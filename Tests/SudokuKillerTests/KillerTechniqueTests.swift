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
}
