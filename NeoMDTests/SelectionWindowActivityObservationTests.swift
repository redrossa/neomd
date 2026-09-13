import AppKit
import Testing
@testable import NeoMD

@MainActor
struct SelectionWindowActivityObservationTests {
    @Test func filtersBothKeyNotificationsAndRebindsWithoutDuplicates() {
        let center = NotificationCenter()
        let first = NSObject(), second = NSObject()
        let observation = SelectionWindowActivityObservation(center: center)
        var calls = 0
        observation.bind(first) { calls += 1 }
        center.post(name: NSWindow.didBecomeKeyNotification, object: second)
        center.post(name: NSWindow.didResignKeyNotification, object: nil)
        #expect(calls == 0)
        center.post(name: NSWindow.didBecomeKeyNotification, object: first)
        center.post(name: NSWindow.didResignKeyNotification, object: first)
        #expect(calls == 2)
        observation.bind(second) { calls += 1 }
        observation.bind(second) { calls += 1 }
        center.post(name: NSWindow.didResignKeyNotification, object: first)
        center.post(name: NSWindow.didBecomeKeyNotification, object: second)
        #expect(calls == 3)
        observation.stop()
        center.post(name: NSWindow.didResignKeyNotification, object: second)
        #expect(calls == 3)
        observation.bind(nil) { calls += 1 }
        center.post(name: NSWindow.didBecomeKeyNotification, object: second)
        #expect(calls == 3)
    }

    @Test func releasesObserverAndDoesNotRetainTarget() {
        let center = NotificationCenter()
        var target: NSObject? = NSObject()
        weak var weakTarget = target
        var observation: SelectionWindowActivityObservation? = SelectionWindowActivityObservation(center: center)
        weak var weakObservation = observation
        var calls = 0
        observation?.bind(target) { calls += 1 }
        target = nil
        #expect(weakTarget == nil)
        observation = nil
        #expect(weakObservation == nil)
        center.post(name: NSWindow.didBecomeKeyNotification, object: nil)
        #expect(calls == 0)
    }
}
