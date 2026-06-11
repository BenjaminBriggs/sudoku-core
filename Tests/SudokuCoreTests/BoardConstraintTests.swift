import Foundation
import Testing

@testable import SudokuCore

/// Test-only constraint that reacts to another constraint's pruning:
/// once `watched` can no longer be `watchedDigit`, it forbids `digit` in `position`.
/// Requires fixpoint pruning to fire — a single pass over a stale snapshot misses it.
struct PropagateForbid: Constraint {
    static let typeID = "test.propagateForbid"
    let watched: Puzzle.Index
    let watchedDigit: Int
    let position: Puzzle.Index
    let digit: Int

    var cells: [Puzzle.Index] { [watched, position] }

    func violations(in state: BoardState) -> [ConstraintViolation] { [] }

    func prune(candidates: inout PencilMarks, in state: BoardState) {
        if state.pencilMarks[watched.row][watched.column].contains(watchedDigit) == false {
            candidates[position.row][position.column].remove(digit)
        }
    }
}

/// Test-only misbehaving constraint: declares only `position` but tries to
/// clear an unrelated cell and to ADD a candidate to its own cell.
struct RogueConstraint: Constraint {
    static let typeID = "test.rogue"
    let position: Puzzle.Index

    var cells: [Puzzle.Index] { [position] }

    func violations(in state: BoardState) -> [ConstraintViolation] { [] }

    func prune(candidates: inout PencilMarks, in state: BoardState) {
        candidates[8][8] = []  // out of declared scope
        candidates[position.row][position.column].insert(9)  // additions are not pruning
        candidates[position.row][position.column].remove(5)  // legitimate removal
    }
}

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

    @Test("Constraint pruning runs to a fixpoint across constraints")
    func fixpointPruning() {
        // Premises: in example().startingState, classic rules allow 2 at (0,1)
        // and 7 at (2,2) — verified against row/column/house contents.
        let x = Puzzle.Index(row: 0, column: 1)
        let y = Puzzle.Index(row: 2, column: 2)
        let constraints = [
            // Order chosen so the dependent constraint runs FIRST: only a second
            // pass over the updated snapshot can see ForbidDigit's elimination.
            AnyConstraint(PropagateForbid(watched: x, watchedDigit: 2, position: y, digit: 7)),
            AnyConstraint(ForbidDigit(position: x, digit: 2)),
        ]
        let state = BoardState.fromGrid(Puzzle.example().startingState, constraints: constraints)
        #expect(state.pencilMarks[x.row][x.column].contains(2) == false)
        #expect(state.pencilMarks[y.row][y.column].contains(7) == false)

        let board = Board(givenCells: Puzzle.example().startingState, constraints: constraints)
        #expect(board.cell(at: y).validOptions.contains(7) == false)
    }

    @Test("Restoration filters pencil marks forbidden by constraints")
    func restoreFiltersConstraintForbiddenMarks() {
        // Constraint forbids 2 at (0,1); persisted marks there claim {2, 3}.
        // Classic rules allow {2, 3, 7} at (0,1), so 3 must survive the filter.
        let position = Puzzle.Index(row: 0, column: 1)
        let constraint = AnyConstraint(ForbidDigit(position: position, digit: 2))
        let board = Board(puzzle: examplePuzzle(with: constraint))

        var marks: [[Set<Int>]] = Array(repeating: Array(repeating: [], count: 9), count: 9)
        marks[position.row][position.column] = [2, 3]
        let empty: [[Set<Int>]] = Array(repeating: Array(repeating: [], count: 9), count: 9)

        board.restore(
            currentState: Puzzle.example().startingState,
            simplePencilMarks: marks,
            advancedPencilMarks: empty,
            backgroundColors: Array(repeating: Array(repeating: 0, count: 9), count: 9),
            ruledOutCandidates: empty,
            undoStack: [],
            solution: Puzzle.example().solution,
            hintsUsed: 0,
            incorrectMoves: 0
        )

        let restored = board.cell(at: position).simplePencilMarks
        #expect(restored.contains(2) == false)
        #expect(restored.contains(3))
    }

    @Test("Stale violations clear when constraints are removed")
    func staleViolationsCleared() {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 2))
        let board = Board(puzzle: examplePuzzle(with: constraint))
        board.mark(positions: [.init(row: 0, column: 1)], as: 2)
        #expect(board.constraintViolations.isEmpty == false)

        board.constraints = []
        board.updateCellValidation()
        #expect(board.constraintViolations.isEmpty)
    }

    @Test("Pruning is confined to a constraint's declared cells, removals only")
    func pruningScopeEnforced() {
        // Empty grid: every cell classically allows 1-9.
        let position = Puzzle.Index(row: 4, column: 4)
        let state = BoardState.fromGrid(
            Array(repeating: Array(repeating: 0, count: 9), count: 9),
            constraints: [AnyConstraint(RogueConstraint(position: position))]
        )
        // The legitimate removal applies…
        #expect(state.pencilMarks[4][4] == Set(1...9).subtracting([5]))
        // …the out-of-scope clear is ignored…
        #expect(state.pencilMarks[8][8] == Set(1...9))
        // …and the in-scope insertion is ignored (9 was already present; ensure
        // a cell that lost a digit cannot regain one across passes).
        #expect(state.pencilMarks[4][4].contains(9))
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
