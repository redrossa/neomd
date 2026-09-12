import Foundation

/// A read failure keeps the authored/attempted path and diagnostic cause separate
/// from plain, actionable reader-facing text. Decoding policy is unchanged.
nonisolated struct DocumentOpenFailure: LocalizedError {
    enum Kind: Error { case missing, inaccessible, unsuitableItem, unreadableText, readFailed }

    let attemptedURL: URL
    let kind: Kind
    let underlyingError: Error

    // Native completion consumers may use only localizedDescription and recovery;
    // keep the path in that description too, not solely in failureReason.
    var errorDescription: String? { "Couldn’t Open Document\n\(failureReason ?? "")" }
    var failureReason: String? {
        let reason: String
        switch kind {
        case .missing: reason = "The file couldn’t be found."
        case .inaccessible: reason = "NeoMD couldn’t access this file."
        case .unsuitableItem: reason = "This item isn’t a readable Markdown file."
        case .unreadableText: reason = "This file couldn’t be read as text."
        case .readFailed: reason = "The file couldn’t be read."
        }
        return "\(reason)\n\(attemptedURL.path)"
    }
    var recoverySuggestion: String? {
        switch kind {
        case .missing:
            "Locate the file if it moved or was renamed, or reconnect its volume, then open it again."
        case .inaccessible:
            "Check file permissions in Finder and NeoMD’s access in System Settings > Privacy & Security, then try again."
        case .unsuitableItem:
            "Choose a Markdown file, such as notes.md, rather than a folder, app or executable."
        case .unreadableText:
            "Obtain or export a text or UTF-8 copy in the app that created it, then open that copy. NeoMD won’t change the original."
        case .readFailed:
            "Check the file and that its volume is connected, then try opening it again."
        }
    }
    var message: String { "\(failureReason ?? "")\n\n\(recoverySuggestion ?? "")" }

    /// Native completion callers own presentation. Preserve cancellation unchanged;
    /// otherwise return one enriched error without presenting it here.
    static func completionError(_ error: Error, at url: URL) -> Error {
        normalized(error, at: url) ?? error
    }

    /// Bounded identity-checked traversal handles generic Cocoa wrappers without
    /// mistaking a corrupt-file wrapper for proof of an encoding problem.
    static func normalized(_ error: Error, at url: URL) -> Self? {
        var current: Error? = error
        var seen = Set<ObjectIdentifier>()
        var kind: Kind?
        for _ in 0..<32 {
            guard let cause = current else { break }
            let ns = cause as NSError
            guard seen.insert(ObjectIdentifier(ns)).inserted else { break }
            if cause is CancellationError || (ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError)
                || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled) { return nil }
            if let failure = cause as? Self {
                if kind == nil, failure.kind != .readFailed { kind = failure.kind }
                current = failure.underlyingError
                continue
            }
            if let specific = classify(cause), specific != .readFailed, kind == nil { kind = specific }
            current = ns.userInfo[NSUnderlyingErrorKey] as? Error
        }
        return Self(attemptedURL: url, kind: kind ?? .readFailed, underlyingError: error)
    }

    private static func classify(_ error: Error) -> Kind? {
        if let kind = error as? Kind { return kind }
        if error is MarkdownTextDecoder.Failure { return .unreadableText }
        if error is MarkdownDocument.Failure { return .unsuitableItem }
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain {
            switch ns.code {
            case Int(ENOENT), Int(ENOTDIR): return .missing
            case Int(EACCES), Int(EPERM): return .inaccessible
            default: return nil
            }
        }
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError: return .missing
            case NSFileReadNoPermissionError: return .inaccessible
            case NSFileReadInapplicableStringEncodingError: return .unreadableText
            default: return nil
            }
        }
        return nil
    }

    static func requireAccessible(_ url: URL) throws -> Bool {
        switch LocalFileAccessProbe.state(of: url) {
        case .readable(let directory): return directory
        case .missing: throw Self(attemptedURL: url, kind: .missing, underlyingError: Kind.missing)
        case .inaccessible: throw Self(attemptedURL: url, kind: .inaccessible, underlyingError: Kind.inaccessible)
        }
    }

    /// Metadata-only preflight; actual descriptor failures are normalized later.
    static func validateMarkdown(_ url: URL) throws {
        guard url.isFileURL, MarkdownFileType.claimsFile(at: url) else { throw Kind.unsuitableItem }
        guard try !requireAccessible(url) else { throw Kind.unsuitableItem }
        let values = try url.standardizedFileURL.resolvingSymlinksInPath()
            .resourceValues(forKeys: [.isApplicationKey, .isExecutableKey])
        guard values.isApplication == false, values.isExecutable == false else { throw Kind.unsuitableItem }
    }
}
