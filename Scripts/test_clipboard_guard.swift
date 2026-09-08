import AppKit
import Foundation

// Integration probes use only a uniquely named pasteboard, never .general.
let boardName = "NeoMD-Clipboard-Lifecycle-\(UUID())"
let board = NSPasteboard(name: NSPasteboard.Name(boardName))
defer { board.releaseGlobally() }
let custom = NSPasteboard.PasteboardType("io.neomd.test.binary")
let binary = Data([0, 255, 12, 0])

func seed() {
    let first = NSPasteboardItem()
    first.setString("private original", forType: .string)
    first.setData(binary, forType: custom)
    let second = NSPasteboardItem()
    second.setString("second private item", forType: .string)
    board.clearContents()
    precondition(board.writeObjects([first, second]))
}

func run(interveningChange: Bool) throws {
    seed()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
    process.arguments = ["--private-board", boardName]
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    try process.run()
    // These fixed protocol responses contain no clipboard representations.
    func response() -> String {
        var result = Data()
        while let byte = try? output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte == Data([10]) { break }
            result.append(byte)
        }
        return String(data: result, encoding: .utf8) ?? ""
    }
    precondition(response() == "ready")
    let command = try JSONSerialization.data(withJSONObject: ["action": "begin", "expected": "fixture copy"])
    try input.fileHandleForWriting.write(contentsOf: command + Data([10]))
    precondition(response() == "ok")
    board.clearContents()
    board.setString("fixture copy", forType: .string)
    if interveningChange {
        board.clearContents()
        board.setString("concurrent private item", forType: .string)
    }
    // No finish command: closing the controller's pipe models controller death.
    try input.fileHandleForWriting.close()
    process.waitUntilExit()
    if interveningChange {
        precondition(process.terminationStatus == 2)
        precondition(board.string(forType: .string) == "concurrent private item")
    } else {
        precondition(process.terminationStatus == 0)
        precondition(board.pasteboardItems?.count == 2)
        precondition(board.pasteboardItems?[0].string(forType: .string) == "private original")
        precondition(board.pasteboardItems?[0].data(forType: custom) == binary)
        precondition(board.pasteboardItems?[1].string(forType: .string) == "second private item")
    }
}

try run(interveningChange: false)
try run(interveningChange: true)
print("Private clipboard guardian EOF and concurrent-change integration tests passed")
