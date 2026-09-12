import Foundation
import Testing
@testable import NeoMD

@MainActor struct ReadingSizePreferenceTests {
    @Test func isolatedPreferenceReloadSharesChoiceAndPreservesUnrelatedKeys() throws {
        let name = "NeoMD.ReadingSizeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("kept", forKey: "unrelated")
        let preference = ReadingSizePreference(defaults: defaults)
        #expect(preference.size == .actual)
        preference.apply(.decrease)
        preference.apply(.reset)
        #expect(defaults.object(forKey: ReadingSizePreference.key) == nil)
        preference.apply(.increase)
        let secondConsumer = preference
        #expect(secondConsumer.size == .large)
        #expect(ReadingSizePreference(defaults: defaults).size == .large)
        secondConsumer.apply(.increase)
        #expect(preference.size == .largest)
        #expect(ReadingSizePreference(defaults: defaults).size == .largest)
        preference.apply(.increase)
        #expect(defaults.double(forKey: ReadingSizePreference.key) == 2)
        preference.apply(.reset)
        #expect(ReadingSizePreference(defaults: defaults).size == .actual)
        #expect(defaults.string(forKey: "unrelated") == "kept")
        #expect(Set(defaults.persistentDomain(forName: name)?.keys.map { $0 } ?? []) == ["unrelated", ReadingSizePreference.key])
    }

    @Test func corruptStoredChoiceDefaultsWithoutWritingOnConstruction() throws {
        let name = "NeoMD.ReadingSizeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for value: Any in [true, "2", 1.25, -2] {
            defaults.set(value, forKey: ReadingSizePreference.key)
            let before = defaults.persistentDomain(forName: name)! as NSDictionary
            #expect(ReadingSizePreference(defaults: defaults).size == .actual)
            #expect(defaults.persistentDomain(forName: name)! as NSDictionary == before)
        }
    }
}
