/// Per-presentation state. Desired commands coalesce while an interaction owns
/// the reader; preparation runs synchronously before any new scale is published.
struct ReadingSizeReflow {
    private(set) var applied: ReadingSize
    private(set) var serial: Int

    init(preference: ReadingSizePreference, initial: ReadingSize? = nil) {
        applied = initial ?? preference.size
        serial = preference.commandSerial
    }

    func isQueued(_ preference: ReadingSizePreference) -> Bool {
        serial != preference.commandSerial
    }

    mutating func reconcile(_ preference: ReadingSizePreference, eligible: Bool,
                            prepare: () -> Void) {
        guard eligible, isQueued(preference) else { return }
        serial = preference.commandSerial
        guard applied != preference.size else { return }
        prepare()
        applied = preference.size
    }

    static func shouldRevealExistingFind(viewportChanged: Bool, hasHighlight: Bool,
                                         sizeOwnsRestoration: Bool) -> Bool {
        viewportChanged && hasHighlight && !sizeOwnsRestoration
    }
}
