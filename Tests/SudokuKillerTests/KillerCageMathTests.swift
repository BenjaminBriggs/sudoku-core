import Foundation
import Testing

@testable import SudokuKiller

struct KillerCageMathTests {

    @Test("Two-cell cage summing to 3 has exactly one combination")
    func uniqueCombination() {
        let combos = KillerCage.combinations(size: 2, sum: 3, excluding: [])
        #expect(combos == [Set([1, 2])])
    }

    @Test("Two-cell cage summing to 10 has multiple combinations")
    func multipleCombinations() {
        let combos = KillerCage.combinations(size: 2, sum: 10, excluding: [])
        let expected: Set<Set<Int>> = [[1, 9], [2, 8], [3, 7], [4, 6]]
        #expect(Set(combos) == expected)
    }

    @Test("Excluded digits remove combinations")
    func exclusions() {
        let combos = KillerCage.combinations(size: 2, sum: 10, excluding: [1, 2])
        let expected: Set<Set<Int>> = [[3, 7], [4, 6]]
        #expect(Set(combos) == expected)
    }

    @Test("Impossible cages have no combinations")
    func impossible() {
        #expect(KillerCage.combinations(size: 2, sum: 18, excluding: []).isEmpty)
        #expect(KillerCage.combinations(size: 3, sum: 5, excluding: []).isEmpty)
        #expect(KillerCage.combinations(size: 1, sum: 5, excluding: []) == [Set([5])])
    }
}
