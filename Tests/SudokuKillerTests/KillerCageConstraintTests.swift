import Foundation
import Testing

@testable import SudokuCore
@testable import SudokuKiller

struct KillerCageConstraintTests {

    /// Grid with only the values we place; everything else empty.
    private func grid(_ entries: [(row: Int, col: Int, value: Int)]) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for e in entries { g[e.row][e.col] = e.value }
        return g
    }

    private let cage = KillerCage(
        cells: [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2)],
        sum: 6  // forces digits {1,2,3}
    )

    @Test("No violations on an empty grid")
    func emptyGrid() {
        let state = BoardState.fromGrid(grid([]))
        #expect(cage.violations(in: state).isEmpty)
    }

    @Test("Duplicate digit in cage is a violation")
    func duplicateDigit() {
        let state = BoardState.fromGrid(grid([(0, 0, 1), (0, 2, 1)]))
        #expect(cage.violations(in: state).count == 1)
    }

    @Test("Exceeding the sum is a violation")
    func sumExceeded() {
        let state = BoardState.fromGrid(grid([(0, 0, 5), (0, 1, 4)]))
        #expect(cage.violations(in: state).isEmpty == false)
    }

    @Test("Complete cage missing the sum is a violation")
    func wrongCompleteSum() {
        let state = BoardState.fromGrid(grid([(0, 0, 1), (0, 1, 2), (0, 2, 4)]))
        #expect(cage.violations(in: state).isEmpty == false)
    }

    @Test("Complete cage hitting the sum is fine")
    func correctCompleteSum() {
        let state = BoardState.fromGrid(grid([(0, 0, 1), (0, 1, 2), (0, 2, 3)]))
        #expect(cage.violations(in: state).isEmpty)
    }

    @Test("Unreachable remaining sum is a violation")
    func unreachableSum() {
        // Cage sum 24 over 3 cells; placing 1 leaves 23 over 2 cells — impossible
        // (max is 8+9=17), but placedSum < sum so naive bounds checks miss it.
        let bigCage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2)],
            sum: 24
        )
        let state = BoardState.fromGrid(grid([(0, 0, 1)]))
        #expect(bigCage.violations(in: state).isEmpty == false)
    }

    @Test("Remaining sum too small for distinct digits is a violation")
    func tooSmallSum() {
        // Sum 6 over 3 cells is exactly {1,2,3}; placing 5 leaves 1 over 2 cells —
        // impossible, yet placedSum + emptyCount (5+2=7) only just exceeds 6.
        let state = BoardState.fromGrid(grid([(0, 0, 5)]))
        #expect(cage.violations(in: state).isEmpty == false)
    }

    @Test("Pruning keeps only combination digits")
    func pruneToCombinations() {
        let state = BoardState.fromGrid(grid([]))
        var candidates = state.validOptions
        cage.prune(candidates: &candidates, in: state)
        // sum 6 over 3 cells => only {1,2,3} possible
        #expect(candidates[0][0] == Set([1, 2, 3]))
        #expect(candidates[0][1] == Set([1, 2, 3]))
        #expect(candidates[0][2] == Set([1, 2, 3]))
        // cells outside the cage untouched
        #expect(candidates[1][0] == Set(1...9))
    }

    @Test("Pruning leaves candidates untouched when the cage is infeasible")
    func pruneInfeasibleCage() {
        // 5 placed: remaining sum 1 over 2 cells is impossible. The violation is
        // the signal; pruning must not clear the cells to an empty candidate set.
        let state = BoardState.fromGrid(grid([(0, 0, 5)]))
        var candidates = state.validOptions
        let before = candidates
        cage.prune(candidates: &candidates, in: state)
        #expect(candidates == before)
    }

    @Test("Pruning respects placed cage digits")
    func pruneWithPlacement() {
        let state = BoardState.fromGrid(grid([(0, 0, 1)]))
        var candidates = state.validOptions
        cage.prune(candidates: &candidates, in: state)
        // remaining two cells must be {2,3}; 1 is excluded by the no-repeat rule
        #expect(candidates[0][1] == Set([2, 3]))
        #expect(candidates[0][2] == Set([2, 3]))
    }
}
