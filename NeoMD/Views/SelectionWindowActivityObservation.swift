import AppKit

/// Owns only key-status notifications for the currently mounted window.
@MainActor
final class SelectionWindowActivityObservation {
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []
    private weak var target: AnyObject?
    private var generation = UUID()

    init(center: NotificationCenter = .default) { self.center = center }

    func bind(_ target: AnyObject?, invalidate: @escaping @MainActor () -> Void) {
        stop()
        self.target = target
        guard let target else { return }
        let generation = self.generation
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            tokens.append(center.addObserver(forName: name, object: target, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, self.generation == generation,
                          let current = self.target, notification.object as AnyObject? === current else { return }
                    invalidate()
                }
            })
        }
    }

    func stop() {
        generation = UUID()
        for token in tokens { center.removeObserver(token) }
        tokens.removeAll()
        target = nil
    }

    deinit {
        for token in tokens { center.removeObserver(token) }
    }
}
