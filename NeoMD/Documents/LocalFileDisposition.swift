import Foundation

/// Every explicit local-file activation, including absolute file: links, passes here.
nonisolated enum LocalFileDisposition: Equatable {
    case markdown, external, reveal

    static func resolve(_ url: URL) throws -> Self {
        let directory = try DocumentOpenFailure.requireAccessible(url)
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let values = try resolved.resourceValues(forKeys: [.isApplicationKey, .isExecutableKey])
        guard let application = values.isApplication, let executable = values.isExecutable else {
            throw MarkdownDocument.Failure.notAReadableFile
        }
        if application || (!directory && executable) { return .reveal }
        return !directory && MarkdownFileType.claimsFile(at: url) ? .markdown : .external
    }
}
