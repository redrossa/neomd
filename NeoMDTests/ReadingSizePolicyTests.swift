import Foundation
import Testing
@testable import NeoMD

struct ReadingSizePolicyTests {
    @Test func allTransitionsAreFiniteAndSaturating() {
        #expect(ReadingSize.allCases.map(\.rawValue) == [1, 1.5, 2])
        let increases: [ReadingSize] = [.large, .largest, .largest]
        let decreases: [ReadingSize] = [.actual, .actual, .large]
        for (index, size) in ReadingSize.allCases.enumerated() {
            #expect(size.applying(.increase) == increases[index])
            #expect(size.applying(.decrease) == decreases[index])
            #expect(size.applying(.reset) == .actual)
        }
    }

    @Test func storedValuesRejectBooleanStringAndUnsupportedNumbers() {
        for value: Any in [true, false, "1.5", "garbage", 0, -1, 1.25,
                           Double.nan, Double.infinity, -Double.infinity, [1.5]] {
            #expect(ReadingSize.decode(value) == .actual)
        }
        #expect(ReadingSize.decode(nil) == .actual)
        #expect(ReadingSize.decode(1.5) == .large)
        #expect(ReadingSize.decode(2) == .largest)
    }
}
