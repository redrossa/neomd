import Darwin
import Foundation

/// Metadata and access checks only: never read a target or open a FIFO/device.
nonisolated enum LocalFileAccessProbe {
    enum State: Equatable, Sendable {
        case readable(isDirectory: Bool), missing, inaccessible
    }

    static func state(of url: URL) -> State {
        guard url.isFileURL else { return .inaccessible }
        var metadata = stat()
        guard stat(url.path, &metadata) == 0 else { return failure(errno) }
        let directory = metadata.st_mode & S_IFMT == S_IFDIR
        // access preserves EACCES/EPERM, including denied ancestors and sandbox denial.
        guard access(url.path, directory ? R_OK | X_OK : R_OK) == 0 else { return failure(errno) }
        // Do not dispatch special files as ordinary documents.
        guard directory || metadata.st_mode & S_IFMT == S_IFREG else { return .inaccessible }
        return .readable(isDirectory: directory)
    }

    private static func failure(_ error: Int32) -> State {
        error == ENOENT || error == ENOTDIR ? .missing : .inaccessible
    }
}
