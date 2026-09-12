import CoreFoundation
import Foundation
import Observation

nonisolated enum ReadingSize: Double, CaseIterable, Sendable {
    case actual = 1
    case large = 1.5
    case largest = 2

    enum Command { case increase, decrease, reset }

    func applying(_ command: Command) -> Self {
        switch command {
        case .increase: self == .actual ? .large : .largest
        case .decrease: self == .largest ? .large : .actual
        case .reset: .actual
        }
    }

    static func decode(_ value: Any?) -> Self {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              let size = Self(rawValue: number.doubleValue) else { return .actual }
        return size
    }
}

/// One app preference, independent of documents and reading history. A nil store
/// is deliberately in-memory; only the production coordinator supplies standard.
@Observable final class ReadingSizePreference {
    static let key = "readingSizeScale"
    private(set) var size: ReadingSize
    private(set) var commandSerial = 0
    @ObservationIgnored private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        size = ReadingSize.decode(defaults?.object(forKey: Self.key))
    }

    func canApply(_ command: ReadingSize.Command, committed: Bool, displayed: ReadingSize?) -> Bool {
        let current = displayed ?? size
        return committed && current.applying(command) != current
    }

    func apply(_ command: ReadingSize.Command) {
        commandSerial += 1
        let next = size.applying(command)
        guard next != size else { return }
        size = next
        defaults?.set(next.rawValue, forKey: Self.key)
    }
}
