import AppKit

/// Copied at activation; never retains a window or consults later keyboard focus.
nonisolated struct DocumentWindowPlacement: Equatable, Sendable {
    struct Screen: Equatable, Sendable {
        let id: UInt32
        let visibleFrame: CGRect
    }

    let sourceFrame: CGRect?
    let screenID: UInt32?
    let capturedVisibleFrame: CGRect?
    static let offset: CGFloat = 24
    static let readerMinimum = CGSize(width: 480, height: 320)

    func selectedScreen(in screens: [Screen]) -> Screen? {
        let usable = screens.filter { Self.isUsable($0.visibleFrame) }
        guard let source = sourceFrame, Self.isUsable(source) else { return usable.first }
        if let screenID, let sourceScreen = usable.first(where: { $0.id == screenID }) {
            return sourceScreen
        }
        let point = CGPoint(x: source.minX, y: source.maxY)
        return usable.min {
            let lhs = Self.distance(point, to: $0.visibleFrame)
            let rhs = Self.distance(point, to: $1.visibleFrame)
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }

    func visibleFrame(in screens: [Screen]) -> CGRect? {
        if let screen = selectedScreen(in: screens) { return screen.visibleFrame }
        return capturedVisibleFrame.flatMap { Self.isUsable($0) ? $0 : nil }
    }

    /// Uses the freshly constructed window's full frame size, including native chrome.
    func frame(defaultSize: CGSize, screens: [Screen]) -> CGRect {
        let size = CGSize(width: Self.validLength(defaultSize.width), height: Self.validLength(defaultSize.height))
        guard let visible = visibleFrame(in: screens) else {
            // No physical visibility claim is possible without any usable display bounds.
            return CGRect(origin: .zero, size: size)
        }
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        let desired: CGPoint
        if let source = sourceFrame, Self.isUsable(source) {
            desired = CGPoint(x: source.minX + Self.offset, y: source.maxY - Self.offset - height)
        } else {
            desired = CGPoint(x: visible.minX + (visible.width - width) / 2,
                              y: visible.minY + (visible.height - height) / 2)
        }
        return CGRect(x: min(max(desired.x, visible.minX), visible.maxX - width),
                      y: min(max(desired.y, visible.minY), visible.maxY - height),
                      width: width, height: height)
    }

    /// The caller supplies AppKit's actual frame-to-content conversion, not a fixed title-bar height.
    static func contentMinimum(available: CGSize) -> CGSize {
        CGSize(width: min(readerMinimum.width, max(0, available.width.isFinite ? available.width : 0)),
               height: min(readerMinimum.height, max(0, available.height.isFinite ? available.height : 0)))
    }

    static func isUsable(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.size.width.isFinite && rect.size.height.isFinite
            && rect.size.width > 0 && rect.size.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }

    private static func validLength(_ value: CGFloat) -> CGFloat {
        value.isFinite && value > 0 ? value : 1
    }

    private static func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        // Equivalent ordering to squared distance, without squaring overflow.
        return hypot(dx, dy)
    }

    @MainActor static func capture(window: NSWindow?) -> Self {
        let screen = window?.screen
        return Self(sourceFrame: window?.frame, screenID: screen.flatMap(displayID),
                    capturedVisibleFrame: screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame)
    }

    @MainActor static func currentScreens() -> [Screen] {
        NSScreen.screens.compactMap { screen in
            displayID(screen).map { Screen(id: $0, visibleFrame: screen.visibleFrame) }
        }
    }

    @MainActor private static func displayID(_ screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
