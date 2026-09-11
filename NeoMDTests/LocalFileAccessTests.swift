import Darwin
import Foundation
import Testing
@testable import NeoMD

struct LocalFileAccessTests {
    @Test func probeDistinguishesReadableMissingAndUnreadable() throws {
        #expect(getuid() != 0, "Permission validation requires a non-root host")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            chmod(folder.path, 0o700)
            try? FileManager.default.removeItem(at: folder)
        }
        let file = folder.appendingPathComponent("private.md")
        try Data("readable".utf8).write(to: file)
        #expect(LocalFileAccessProbe.state(of: file) == .readable(isDirectory: false))
        #expect(LocalFileAccessProbe.state(of: folder) == .readable(isDirectory: true))
        #expect(LocalFileAccessProbe.state(of: folder.appendingPathComponent("absent")) == .missing)
        #expect(LocalFileAccessProbe.state(of: file.appendingPathComponent("child")) == .missing)
        chmod(file.path, 0)
        #expect(LocalFileAccessProbe.state(of: file) == .inaccessible)
        chmod(file.path, 0o600)
        chmod(folder.path, 0)
        #expect(LocalFileAccessProbe.state(of: file) == .inaccessible)
        #expect(LocalFileAccessProbe.state(of: folder.appendingPathComponent("absent")) == .inaccessible)
        chmod(folder.path, 0o700)
        let fifo = folder.appendingPathComponent("pipe.md")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        #expect(LocalFileAccessProbe.state(of: fifo) == .inaccessible)
    }

    // #43 removes the enclosing-folder grant policy; its folder-suggestion assertion is superseded.

}
