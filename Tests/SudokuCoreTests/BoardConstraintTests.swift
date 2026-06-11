import Foundation
import Testing

@testable import SudokuCore

@MainActor
struct BoardConstraintTests {

    private func examplePuzzle(with constraint: AnyConstraint) -> Puzzle {
        Puzzle(
            solution: Puzzle.example().solution,
            startingState: Puzzle.example().startingState,
            difficulty: Puzzle.example().difficulty,
            constraints: [constraint]
        )
    }

    @Test("Constraints prune Board cell validOptions")
    func boardPruning() {
        // (0,1) is empty in example(); classic rules allow 2 there (the solution value),
        // the constraint must remove it.
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let board = Board(puzzle: examplePuzzle(with: constraint))
        let options = board.cell(at: .init(row: 0, column: 1)).validOptions
        #expect(options.contains(2) == false)
    }

    @Test("Constraint violations surface on the Board")
    func boardViolations() {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let board = Board(puzzle: examplePuzzle(with: constraint))
        #expect(board.constraintViolations.isEmpty)
        board.mark(positions: [.init(row: 0, column: 1)], as: 2)
        #expect(board.constraintViolations.count == 1)
        #expect(board.constraintViolations.first?.cells == [Puzzle.Index(row: 0, column: 1)])
    }

    @Test("BoardState.fromGrid applies constraint pruning")
    func stateFromGrid() {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let state = BoardState.fromGrid(Puzzle.example().startingState, constraints: [constraint])
        #expect(state.pencilMarks[0][1].contains(2) == false)
        #expect(state.constraints == [constraint])
    }

    @Test("applying a hint preserves constraints and re-prunes")
    func applyingPreservesConstraints() throws {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let state = BoardState.fromGrid(Puzzle.example().startingState, constraints: [constraint])
        let next = state.applying(try #require(HintFinder.firstHint(in: state)))
        #expect(next.constraints == [constraint])
        if next.grid[0][1] == 0 {
            #expect(next.pencilMarks[0][1].contains(2) == false)
        }
    }

    @Test("Board.state carries constraints")
    func boardStateCarriesConstraints() {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let board = Board(puzzle: examplePuzzle(with: constraint))
        #expect(board.state.constraints == [constraint])
    }

    @Test("BoardState.isSolved requires constraints to be satisfied")
    func isSolvedRespectsConstraints() {
        let fullGrid = Puzzle.example().solution
        // fullGrid[0][1] == 2: a constraint forbidding it is violated by this grid.
        let violated = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let satisfied = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 9))

        #expect(BoardState.fromGrid(fullGrid).isSolved)
        #expect(BoardState.fromGrid(fullGrid, constraints: [satisfied]).isSolved)
        #expect(BoardState.fromGrid(fullGrid, constraints: [violated]).isSolved == false)
    }

    @Test("Board completion requires constraints to be satisfied")
    func boardCompletionRespectsConstraints() {
        var almostDone = Puzzle.example().solution
        almostDone[0][1] = 0  // solution value 2
        // No known solution attached: completion goes through classic validity checking.
        let violated = Board(
            givenCells: almostDone,
            constraints: [AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))]
        )
        violated.mark(positions: [.init(row: 0, column: 1)], as: 2)
        #expect(violated.isSolved == false)

        let satisfied = Board(
            givenCells: almostDone,
            constraints: [AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 9))]
        )
        satisfied.mark(positions: [.init(row: 0, column: 1)], as: 2)
        #expect(satisfied.isSolved)
    }
}
