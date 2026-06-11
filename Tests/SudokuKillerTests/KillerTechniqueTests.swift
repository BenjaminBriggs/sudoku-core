import Foundation
import Testing

@testable import SudokuCore
@testable import SudokuKiller

struct KillerTechniqueTests {

    private func grid(_ entries: [(row: Int, col: Int, value: Int)]) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for e in entries { g[e.row][e.col] = e.value }
        return g
    }

    @Test("CageLastCell solves the final cell of a cage")
    func lastCell() throws {
        let cage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1)],
            sum: 9
        )
        let state = BoardState.fromGrid(
            grid([(0, 0, 4)]),
            constraints: [AnyConstraint(cage)]
        )
        let hint = try #require(CageLastCell().findHint(in: state))
        #expect(hint.technique.id == TechniqueID(rawValue: "killer.cageLastCell"))
        #expect(hint.actions.count == 1)
        let action = try #require(hint.actions.first)
        #expect(action.position == Puzzle.Index(row: 0, column: 1))
        guard case .solveAs(let value) = action.action else {
            Issue.record("Expected solveAs action")
            return
        }
        #expect(value == 5)
        #expect(hint.reasoning.placements.count == 1)
        #expect(hint.reasoning.focusDigits == [5])
    }

    @Test("CageLastCell returns nil with no near-complete cage")
    func lastCellNil() {
        let cage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1)],
            sum: 9
        )
        let state = BoardState.fromGrid(grid([]), constraints: [AnyConstraint(cage)])
        #expect(CageLastCell().findHint(in: state) == nil)
    }

    @Test("CageLastCell returns nil when constraints have no cages")
    func lastCellNoCages() {
        let state = BoardState.fromGrid(grid([]))
        #expect(CageLastCell().findHint(in: state) == nil)
    }

    @Test("CageCombinations eliminates non-combination candidates")
    func combinations() throws {
        // 2-cell cage, sum 4 => only {1,3}: eliminate 2 and 4-9 from both cells.
        let cage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1)],
            sum: 4
        )
        // Build state WITHOUT cage pruning so eliminations exist to find:
        var state = BoardState.fromGrid(grid([]))
        state.constraints = [AnyConstraint(cage)]

        let hint = try #require(CageCombinations().findHint(in: state))
        #expect(hint.technique.id == TechniqueID(rawValue: "killer.cageCombinations"))
        let eliminated = hint.actions.compactMap { action -> Int? in
            guard case .ruleOut(let digit) = action.action else { return nil }
            return digit
        }
        #expect(eliminated.isEmpty == false)
        #expect(Set(eliminated).isDisjoint(with: [1, 3]))
        #expect(hint.reasoning.eliminations.count == hint.actions.count)
    }

    @Test("CageCombinations does not eliminate from infeasible cages")
    func combinationsInfeasible() {
        // Remaining sum unreachable: eliminating "everything" would brick the
        // board; validation reports the breach instead.
        let cage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2)],
            sum: 24
        )
        var state = BoardState.fromGrid(grid([(0, 0, 1)]))
        state.constraints = [AnyConstraint(cage)]
        #expect(CageCombinations().findHint(in: state) == nil)
    }

    @Test("CageCombinations returns nil when pencil marks already match")
    func combinationsNil() {
        let cage = KillerCage(
            cells: [.init(row: 0, column: 0), .init(row: 0, column: 1)],
            sum: 4
        )
        // fromGrid applies cage pruning, so there is nothing left to eliminate.
        let state = BoardState.fromGrid(grid([]), constraints: [AnyConstraint(cage)])
        #expect(CageCombinations().findHint(in: state) == nil)
    }
}
