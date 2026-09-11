//
//  ReadingHistoryObservation.swift
//  NeoMD
//

import Foundation

/// One accepted reading observation for a document.
///
/// The serial is allocated when the observation succeeds, not when it is eventually
/// written, so the last place actually read wins regardless of the order in which
/// readers are closed or the application is quit.
nonisolated struct ReadingHistoryObservation: Equatable, Sendable {
    let url: URL
    let locator: ReadingHistoryLocator
    let serial: Int
    let epoch: Int
}

/// Allocates monotonic observation serials for every reader in the process.
@MainActor final class ReadingHistorySerialAllocator {
    private var value = 0

    init() {}

    func next() -> Int {
        value += 1
        return value
    }
}

/// One reader's cache of its last successful stable capture.
///
/// An idle reader that republishes the same position is not a new reading action and
/// allocates no serial, so it cannot outrank a genuinely newer position elsewhere.
/// Remapping the same logical location across a resize or refresh keeps the original
/// serial, and close, replacement and termination flush that original serial.
nonisolated struct ReadingHistoryCapture: Equatable, Sendable {
    private(set) var observation: ReadingHistoryObservation?

    init() {}

    /// Whether this is a genuinely new reading position for this reader. A serial is
    /// allocated by the caller only when this is `true`, so idle geometry from an
    /// unchanged reader never outranks a newer position elsewhere.
    func isNewObservation(url: URL, locator: ReadingHistoryLocator, epoch: Int) -> Bool {
        guard locator.isWellFormed else { return false }
        guard let observation else { return true }
        if observation.epoch > epoch { return false }
        if observation.epoch != epoch { return true }
        return observation.url != url || observation.locator != locator
    }

    /// Caches an accepted observation with the serial allocated for it.
    mutating func accept(_ accepted: ReadingHistoryObservation) {
        observation = accepted
    }

    /// Re-projects the cached position into a new rendering without claiming that new
    /// reading occurred. Automatic refresh and resize remapping use this.
    @discardableResult
    mutating func remap(_ locator: ReadingHistoryLocator) -> ReadingHistoryObservation? {
        guard let current = observation, locator.isWellFormed, locator != current.locator else {
            return nil
        }
        let remapped = ReadingHistoryObservation(url: current.url, locator: locator,
                                                 serial: current.serial, epoch: current.epoch)
        observation = remapped
        return remapped
    }

    /// The cached observation, with its original serial, for a close, replacement or
    /// termination flush. A flush never allocates a newer serial.
    func flushed(epoch: Int) -> ReadingHistoryObservation? {
        guard let observation, observation.epoch == epoch else { return nil }
        return observation
    }

    mutating func invalidate() {
        observation = nil
    }
}
