import Foundation
import Testing
@testable import NeoMD

struct YAMLMetadataParserTests {
    @Test func semanticFixtures() throws {
        for item in try metadataFixtureCases("metadata-cases.json") {
            let id = item["id"] as! String
            let payload = item["payload"] as! String
            let result = MarkdownFrontMatter.extract("---\n" + payload + "---\n# BODY\n")!
            if item["result"] as? String == "literal-fallback" {
                guard case .literal(let source) = result.content else { Issue.record("Expected fallback: \(id)"); continue }
                #expect(String(source) == "---\n" + payload + "---\n")
                continue
            }
            guard case .formatted(let metadata) = result.content else { Issue.record("Expected table: \(id)"); continue }
            if let pairs = item["orderedPairs"] as? [[String]] {
                let dataRows = metadata.rows.filter { !$0.key.hasSuffix(" › Tag") }
                #expect(dataRows.map { [$0.key, $0.value] } == pairs, "\(id)")
            }
            if let value = item["value"] as? String { #expect(metadata.rows.contains { $0.value == value }, "\(id)") }
            if let value = item["ownedScalar"] as? String { #expect(metadata.rows.contains { $0.value == value }) }
            if let contexts = item["leafContexts"] as? [[String: Any]] {
                for context in contexts {
                    let path = (context["path"] as! [Any]).map { value in
                        if let number = value as? Int { return "Item \(number)" }
                        return value as! String
                    }.joined(separator: " › ")
                    #expect(metadata.rows.contains { $0.key == path && $0.value == context["text"] as? String }, "\(id)")
                }
            }
            if id == "empty-forms" {
                #expect(metadata.rows.map(\.value) == ["Empty string", "Empty value", "Empty mapping", "Empty sequence"])
            }
            if id == "structured-key" {
                #expect(metadata.rows.map(\.key) == ["Entry 1 › Key › Item 1", "Entry 1 › Key › Item 2", "Entry 1 › Value"])
                #expect(metadata.rows.map(\.value) == ["one", "two", "value"])
            }
            if id == "inert-tags" {
                #expect(metadata.rows.filter { $0.key.hasSuffix(" › Tag") }.map(\.value) == ["!report", "tag:yaml.org,2002:str", "tag:yaml.org,2002:binary"])
            }
        }
    }

    @Test func exactInputDepthAndNodeLimits() throws {
        for count in [262135, 262136, 262137] {
            let payload = "value: " + String(repeating: "x", count: count) + "\n"
            #expect(succeeds(payload) == (count <= 262136))
        }
        for depth in [63, 64, 65] {
            let payload = String(repeating: "[", count: depth) + "x" + String(repeating: "]", count: depth) + "\n"
            #expect(succeeds(payload) == (depth <= 64))
        }
        for count in [9998, 9999, 10000] {
            let payload = "[" + Array(repeating: "x", count: count).joined(separator: ",") + "]\n"
            #expect(succeeds(payload) == (count <= 9999))
        }
    }

    @Test func exactEventVisitAndOutputAccounting() {
        // x: five events. value: x: three visits (mapping, key, value), six bytes (value + x).
        for cap in [4, 5, 6] {
            var limits = YAMLMetadataLimits(); limits.events = cap
            #expect(succeeds("x\n", limits: limits) == (cap >= 5))
        }
        for cap in [2, 3, 4] {
            var limits = YAMLMetadataLimits(); limits.visits = cap
            #expect(succeeds("value: x\n", limits: limits) == (cap >= 3))
        }
        for cap in [5, 6, 7] {
            var limits = YAMLMetadataLimits(); limits.outputBytes = cap
            #expect(succeeds("value: x\n", limits: limits) == (cap >= 6))
        }
        #expect(!succeeds("x\n---\ny\n")) // no accepting a valid prefix
    }

    @Test func aliasAmplificationIsBoundedAndLossless() {
        var bomb = "a0: &a0 [x, x]\n"
        for index in 1...16 { bomb += "a\(index): &a\(index) [*a\(index - 1), *a\(index - 1)]\n" }
        bomb += "result: *a16\n"
        var output = "a: &a " + String(repeating: "x", count: 20_000) + "\n"
        for index in 0..<64 { output += "b\(index): *a\n" }
        for payload in [bomb, output, "a: &a [*a]\n"] {
            let source = "---\n" + payload + "---\n# BODY\n"
            let result = MarkdownFrontMatter.extract(source)!
            guard case .literal(let candidate) = result.content else { Issue.record("Expected bounded recovery"); continue }
            #expect(String(candidate) + result.body == source)
            #expect(result.body == "# BODY\n")
        }
    }

    @Test func independentConcurrentParsers() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<32 {
                group.addTask {
                    let result = try YAMLMetadataParser.parse(Substring("a: &a value\(index)\nb: *a\n"))
                    #expect(result.rows.map(\.value) == ["value\(index)", "value\(index)"])
                    #expect(!succeeds("a: *missing\n"))
                }
            }
            try await group.waitForAll()
        }
    }
}

private func succeeds(_ payload: String, limits: YAMLMetadataLimits = .init()) -> Bool {
    (try? YAMLMetadataParser.parse(Substring(payload), limits: limits)) != nil
}

func metadataFixtureCases(_ file: String) throws -> [[String: Any]] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("docs/fixtures/m1-15-content/" + file)
    // JSONSerialization bridges NSString and strips one leading BOM from a
    // string on this host. Decode native Swift strings to preserve fixture bytes.
    let object = try JSONDecoder().decode([String: MetadataFixtureJSON].self, from: Data(contentsOf: url))
    return object["cases"]!.value as! [[String: Any]]
}

private enum MetadataFixtureJSON: Decodable {
    case string(String), number(Int), bool(Bool), array([Self]), object([String: Self]), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let text = try? value.decode(String.self) { self = .string(text) }
        else if let flag = try? value.decode(Bool.self) { self = .bool(flag) }
        else if let number = try? value.decode(Int.self) { self = .number(number) }
        else if let array = try? value.decode([Self].self) { self = .array(array) }
        else { self = .object(try value.decode([String: Self].self)) }
    }

    var value: Any {
        switch self {
        case .string(let text): text
        case .number(let number): number
        case .bool(let flag): flag
        case .array(let array): array.map(\.value)
        case .object(let object): object.mapValues(\.value)
        case .null: NSNull()
        }
    }
}
