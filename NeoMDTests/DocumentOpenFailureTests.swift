import Foundation
import Testing
@testable import NeoMD

struct DocumentOpenFailureTests {
    private let url = URL(fileURLWithPath: "/attempted folder/café alias.MD")

    @Test func specificCausesSurviveGenericWrappersAndKeepAttemptedPath() throws {
        let cases: [(Error, DocumentOpenFailure.Kind)] = [
            (POSIXError(.ENOENT), .missing), (POSIXError(.ENOTDIR), .missing),
            (CocoaError(.fileNoSuchFile), .missing), (CocoaError(.fileReadNoSuchFile), .missing),
            (POSIXError(.EACCES), .inaccessible), (POSIXError(.EPERM), .inaccessible),
            (CocoaError(.fileReadNoPermission), .inaccessible),
            (MarkdownDocument.Failure.notAReadableFile, .unsuitableItem),
            (MarkdownTextDecoder.Failure.unrecognizedTextEncoding, .unreadableText),
            (CocoaError(.fileReadInapplicableStringEncoding), .unreadableText),
            (POSIXError(.EIO), .readFailed), (POSIXError(.ENXIO), .readFailed),
            (RegularMarkdownRead.SnapshotFailure.unstable, .readFailed),
            (CocoaError(.fileReadCorruptFile), .readFailed), (CocoaError(.fileReadUnknown), .readFailed)
        ]
        for (cause, kind) in cases {
            for error in [cause, NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError,
                                        userInfo: [NSUnderlyingErrorKey: cause])] {
                let failure = try #require(DocumentOpenFailure.normalized(error, at: url))
                #expect(failure.kind == kind && failure.attemptedURL == url)
                #expect(failure.message.contains(url.path))
                #expect(failure.errorDescription?.hasPrefix("Couldn’t Open Document") == true)
                #expect(failure.localizedDescription.contains(url.path))
                #expect(failure.recoverySuggestion?.isEmpty == false)
                #expect((failure.underlyingError as NSError) == (error as NSError))
                for technical in ["POSIXError", "NSCocoaErrorDomain", "NSError", "Error Domain=", "SnapshotFailure", "Optional("] {
                    #expect(!failure.message.contains(technical))
                }
            }
        }
    }

    @Test func cancellationIsSilentAndCompletionOnlyEnrichesActualFailure() throws {
        for cause: Error in [CancellationError(), CocoaError(.userCancelled), URLError(.cancelled)] {
            for error in [cause, NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                                        userInfo: [NSUnderlyingErrorKey: cause])] {
                #expect(DocumentOpenFailure.normalized(error, at: url) == nil)
                #expect((DocumentOpenFailure.completionError(error, at: url) as NSError) == (error as NSError))
            }
        }
        let completion = try #require(DocumentOpenFailure.completionError(POSIXError(.ENOENT), at: url)
            as? DocumentOpenFailure)
        #expect(completion.attemptedURL == url && completion.kind == .missing)
        #expect(completion.message.contains("open it again"))
        #expect((completion as NSError).localizedDescription.contains(url.path))
        #expect((completion as NSError).localizedRecoverySuggestion?.contains("open it again") == true)
    }

    @Test func boundedChainsAndGenericNormalizedWrappersPreferSpecificInnerCause() throws {
        var error: Error = POSIXError(.EACCES)
        for _ in 0..<20 {
            error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                            userInfo: [NSUnderlyingErrorKey: error])
        }
        #expect(DocumentOpenFailure.normalized(error, at: url)?.kind == .inaccessible)
        let wrapped = DocumentOpenFailure(attemptedURL: URL(fileURLWithPath: "/resolved.md"),
                                          kind: .readFailed, underlyingError: error)
        #expect(DocumentOpenFailure.normalized(wrapped, at: url)?.kind == .inaccessible)
        for _ in 0..<80 {
            error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                            userInfo: [NSUnderlyingErrorKey: error])
        }
        #expect(DocumentOpenFailure.normalized(error, at: url)?.kind == .readFailed)
    }

    private final class CyclicError: NSError, @unchecked Sendable {
        init() { super.init(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: nil) }
        required init?(coder: NSCoder) { nil }
        override var userInfo: [String: Any] { [NSUnderlyingErrorKey: self] }
    }

    @Test func cyclicUnderlyingErrorTerminatesWithoutExposingDiagnostics() {
        let failure = DocumentOpenFailure.normalized(CyclicError(), at: url)
        #expect(failure?.kind == .readFailed)
        #expect(failure?.message.contains(url.path) == true)
    }

    @Test func metadataPreflightRetainsMissingPathAndRejectsDirectoryWithoutReadingIt() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let missing = folder.appendingPathComponent("missing café.md")
        do { try DocumentOpenFailure.validateMarkdown(missing); Issue.record("Expected missing") }
        catch { #expect(DocumentOpenFailure.normalized(error, at: missing)?.kind == .missing) }
        do { _ = try LocalFileDisposition.resolve(missing); Issue.record("Expected missing link") }
        catch { #expect(DocumentOpenFailure.normalized(error, at: missing)?.kind == .missing) }
        let directory = folder.appendingPathComponent("folder.md")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do { try DocumentOpenFailure.validateMarkdown(directory); Issue.record("Expected unsuitable") }
        catch { #expect(DocumentOpenFailure.normalized(error, at: directory)?.kind == .unsuitableItem) }
        #expect(try LocalFileDisposition.resolve(directory) == .external)
    }
}
