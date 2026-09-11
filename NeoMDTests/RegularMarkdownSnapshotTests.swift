import Foundation
import Testing
@testable import NeoMD

struct RegularMarkdownSnapshotTests {
    @Test func freshPathReadsAtomicReplacementWithoutChangingSource() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("document.md")
        try Data("first".utf8).write(to: url)
        let first = try RegularMarkdownRead.snapshot(at: url)
        try Data("other".utf8).write(to: url, options: .atomic)
        let before = try RegularMarkdownRead.stamp(at: url)
        let second = try RegularMarkdownRead.snapshot(at: url)
        #expect(second.data == Data("other".utf8))
        #expect(first.stamp.inode != second.stamp.inode)
        #expect(second.stamp == before)
        #expect(try RegularMarkdownRead.stamp(at: url) == before)
        #expect(try Data(contentsOf: url) == second.data)
    }

    @Test func replacementInsideReadIsRejectedAndNextReadRecovers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("document.md")
        try Data("before".utf8).write(to: url)
        #expect(throws: RegularMarkdownRead.SnapshotFailure.self) {
            try RegularMarkdownRead.snapshot(at: url) {
                try Data("after".utf8).write(to: url, options: .atomic)
            }
        }
        #expect(try RegularMarkdownRead.snapshot(at: url).data == Data("after".utf8))
        try Data().write(to: url, options: .atomic)
        #expect(try RegularMarkdownRead.snapshot(at: url).data.isEmpty)
    }
}
