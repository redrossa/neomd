import AppKit
import Foundation

// Private in-memory snapshots only. Never print or persist pasteboard contents.
// The controller owns stdin. EOF (including controller death) invokes restoration.
final class ClipboardLease {
    let board: NSPasteboard
    private var saved: [[(NSPasteboard.PasteboardType, Data)]]?
    private var count = 0
    private var expected = ""

    init(board: NSPasteboard) { self.board = board }

    func begin(expected: String) -> Bool {
        guard saved == nil else { return false }
        let before = board.changeCount
        var snapshot: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in board.pasteboardItems ?? [] {
            var representations: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { return false }
                representations.append((type, data))
            }
            snapshot.append(representations)
        }
        guard board.changeCount == before else { return false }
        saved = snapshot
        count = before
        self.expected = expected
        return true
    }

    func finish() -> Bool {
        guard let snapshot = saved else { return true }
        defer { saved = nil; expected = "" }
        let current = board.changeCount
        if current == count { return true } // No copy took place.
        // One native copy must be the only ownership change. Any other change
        // fails closed, even if it happens to contain the expected fixture text.
        guard current == count + 1,
              board.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) == expected else { return false }
        let items = snapshot.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations { item.setData(data, forType: type) }
            return item
        }
        guard board.changeCount == current else { return false }
        board.clearContents()
        return items.isEmpty || board.writeObjects(items)
    }
}

func selfTest() {
    let board = NSPasteboard(name: NSPasteboard.Name("NeoMD-Clipboard-Probe-\(UUID())"))
    defer { board.releaseGlobally() }
    let original = NSPasteboardItem()
    original.setString("private fixture", forType: .string)
    let custom = NSPasteboard.PasteboardType("io.neomd.test.binary")
    let bytes = Data([0, 255, 127, 0])
    original.setData(bytes, forType: custom)
    board.clearContents()
    precondition(board.writeObjects([original]))
    let lease = ClipboardLease(board: board)
    precondition(lease.begin(expected: "copied fixture"))
    board.clearContents()
    precondition(board.setString("copied fixture", forType: .string))
    precondition(lease.finish())
    precondition(board.string(forType: .string) == "private fixture")
    precondition(board.data(forType: custom) == bytes)
    precondition(lease.begin(expected: "copied fixture"))
    precondition(lease.finish()) // Interrupted before any mutation.
    precondition(lease.begin(expected: "copied fixture"))
    board.clearContents()
    board.setString("copied fixture", forType: .string)
    board.clearContents()
    board.setString("concurrent private fixture", forType: .string)
    precondition(!lease.finish())
    precondition(board.string(forType: .string) == "concurrent private fixture")
    precondition(lease.begin(expected: "copied fixture"))
    board.clearContents()
    board.setString("unexpected private fixture", forType: .string)
    precondition(!lease.finish())
    precondition(board.string(forType: .string) == "unexpected private fixture")
    print("Private clipboard lease tests passed")
}

let arguments = CommandLine.arguments
if arguments.dropFirst() == ["--self-test"] { selfTest(); exit(0) }
// Test mode never reads or changes the general pasteboard.
let board = arguments.count == 3 && arguments[1] == "--private-board"
    ? NSPasteboard(name: NSPasteboard.Name(arguments[2])) : NSPasteboard.general
let lease = ClipboardLease(board: board)
print("ready")
fflush(stdout)
while let line = readLine() {
    var success = false
    if let data = line.data(using: .utf8),
       let command = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
        switch command["action"] {
        case "begin":
            if let expected = command["expected"] { success = lease.begin(expected: expected) }
        case "finish": success = lease.finish()
        default: break
        }
    }
    print(success ? "ok" : "refused")
    fflush(stdout)
}
exit(lease.finish() ? 0 : 2)
