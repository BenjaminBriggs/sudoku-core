//
//  HintValidationRuledOutTests.swift
//  SudokuCore
//
//  Validation catching an empty cell whose answer has been ruled out, and the hint that rules
//  it back in.
//

import Testing

@testable import SudokuCore

@MainActor
struct HintValidationRuledOutTests {

    let givens: [[Int]] = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9]
    ]

    let solution: [[Int]] = [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9]
    ]

    /// r1c4 can only be 2 or 6, and its answer is 6.
    let twoOptionCell = Puzzle.Index(row: 0, column: 3)
    /// r1c6 can be 2, 4, 6 or 8, and its answer is 8.
    let fourOptionCell = Puzzle.Index(row: 0, column: 5)

    func makeBoard(withSolution: Bool = true) -> Board {
        Board(difficulty: .easy, givenCells: givens, solution: withSolution ? solution : nil)
    }

    // MARK: - Detection

    @Test("A ruled-out answer is the first hint, ahead of the wrong single it would lead to")
    func ruledOutAnswerIsFound() throws {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 6)
        // The engine now reads r1c4 as a naked single of 2, which isn't its answer.
        #expect(board.state.pencilMarks[0][3] == [2])

        let hint = try #require(HintFinder.firstHint(in: board.state))

        #expect(hint.technique == .validation)
        #expect(hint.actions == [HintAction(position: twoOptionCell, ruleIn: 6)])
        #expect(hint.reasoning.focusDigits == [6])
        #expect(hint.reasoning.units.isEmpty)
        #expect(hint.reasoning.placements.isEmpty)
        #expect(hint.reasoning.eliminations.isEmpty)
        // One subject: the cell as it is, empty and without the answer among its candidates.
        #expect(hint.reasoning.components == [
            HintComponent(role: .subject, cells: [CellFact(position: twoOptionCell, candidates: [2])])
        ])
        #expect(hint.reasoning.inconsistencies(in: board.state).isEmpty)
    }

    @Test("Ruling out a number that isn't the answer is no mistake")
    func ruledOutNonAnswerIsFine() {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 2)
        board.ruleOut(positions: [fourOptionCell], as: 4)
        #expect(HintFinder.findHint(for: .validation, in: board.state) == nil)
    }

    @Test("Without a solution, a ruled-out answer can't be told from a good rule-out")
    func noSolutionNoHint() {
        let board = makeBoard(withSolution: false)
        board.ruleOut(positions: [twoOptionCell], as: 6)
        #expect(HintFinder.findHint(for: .validation, in: board.state) == nil)
    }

    @Test("One cell per hint, in row-major order")
    func oneCellPerHint() throws {
        let board = makeBoard()
        board.ruleOut(positions: [fourOptionCell], as: 8)
        board.ruleOut(positions: [twoOptionCell], as: 6)

        let first = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(first.actions == [HintAction(position: twoOptionCell, ruleIn: 6)])

        board.apply(hint: first)
        let second = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(second.actions == [HintAction(position: fourOptionCell, ruleIn: 8)])

        board.apply(hint: second)
        #expect(HintFinder.findHint(for: .validation, in: board.state) == nil)
    }

    // MARK: - Order

    @Test("A clash comes before a ruled-out answer")
    func clashFirst() throws {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 6)
        // r1c3 clashes with the given 5 at r1c1.
        board.mark(positions: [Puzzle.Index(row: 0, column: 2)], as: 5)

        let hint = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(hint.reasoning.components.contains { $0.role == .constraint })
        #expect(hint.actions.allSatisfy { $0.action == .clear })
    }

    @Test("A wrong number comes before a ruled-out answer, even one later in the grid")
    func wrongNumberFirst() throws {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 6)
        // r5c3's answer is 6. A 2 there is wrong but clashes with nothing.
        let wrongCell = Puzzle.Index(row: 4, column: 2)
        board.mark(positions: [wrongCell], as: 2)

        let hint = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(hint.actions == [HintAction(clearPosition: wrongCell)])
    }

    @Test("A wrong number that makes the ruled-out answer invalid is reported, then the answer")
    func wrongNumberMakingAnswerInvalid() throws {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 6)
        // A 6 in r1c6 is wrong (its answer is 8) and takes 6 out of r1c4's valid options.
        board.mark(positions: [fourOptionCell], as: 6)
        #expect(board.cell(at: twoOptionCell).validOptions.contains(6) == false)

        let wrongNumber = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(wrongNumber.actions == [HintAction(clearPosition: fourOptionCell)])

        board.apply(hint: wrongNumber)
        let ruledOut = try #require(HintFinder.findHint(for: .validation, in: board.state))
        #expect(ruledOut.actions == [HintAction(position: twoOptionCell, ruleIn: 6)])
    }

    // MARK: - Applying

    @Test("Applying the hint rules back in the answer and nothing else")
    func applyingRestoresOneCandidate() throws {
        let board = makeBoard()
        board.pencil(positions: [fourOptionCell], as: 4)
        board.advancedPencil(positions: [fourOptionCell], as: 6)
        board.ruleOut(positions: [fourOptionCell], as: 2)
        board.ruleOut(positions: [fourOptionCell], as: 8)
        board.ruleOut(positions: [twoOptionCell], as: 2)

        let hint = try #require(HintFinder.firstHint(in: board.state))
        board.apply(hint: hint)

        let cell = board.cell(at: fourOptionCell)
        #expect(cell.ruledOutCandidates == [2])
        #expect(cell.simplePencilMarks == [4])
        #expect(cell.advancedPencilMarks == [6])
        #expect(cell.value == nil)
        #expect(board.cell(at: twoOptionCell).ruledOutCandidates == [2])
        #expect(board.state.pencilMarks[0][5] == [4, 6, 8])
        #expect(board.hintsUsed == 1)
    }

    @Test("Applying the hint is one undo step")
    func applyingIsOneUndoStep() throws {
        let board = makeBoard()
        board.ruleOut(positions: [fourOptionCell], as: 8)
        board.ruleOut(positions: [fourOptionCell], as: 2)
        let before = board.cells
        let steps = board.undoStack.count

        board.apply(hint: try #require(HintFinder.firstHint(in: board.state)))
        #expect(board.undoStack.count == steps + 1)
        #expect(board.cell(at: fourOptionCell).ruledOutCandidates == [2])

        board.undo()
        #expect(board.cells == before)
        #expect(board.cell(at: fourOptionCell).ruledOutCandidates == [2, 8])
    }

    @Test("Ruling in records an undo step only when it changes something, and skips filled cells")
    func ruleInUndo() {
        let board = makeBoard()
        board.ruleOut(positions: [fourOptionCell], as: 8)
        let steps = board.undoStack.count

        board.ruleIn(positions: [fourOptionCell], as: 2)
        #expect(board.undoStack.count == steps, "2 wasn't ruled out, so nothing changed")

        board.ruleIn(positions: [fourOptionCell], as: 8)
        #expect(board.undoStack.count == steps + 1)
        #expect(board.cell(at: fourOptionCell).ruledOutCandidates.isEmpty)

        board.undo()
        #expect(board.cell(at: fourOptionCell).ruledOutCandidates == [8])

        let given = Puzzle.Index(row: 0, column: 0)
        board.ruleIn(positions: [given], as: 5)
        #expect(board.cell(at: given).value == 5)
    }

    @Test("A board state applying the hint gets the answer back among its candidates")
    func stateApplyingRulesIn() throws {
        let board = makeBoard()
        board.ruleOut(positions: [twoOptionCell], as: 6)
        let state = board.state
        let hint = try #require(HintFinder.findHint(for: .validation, in: state))

        let next = state.applying(hint)
        #expect(next.pencilMarks[0][3] == [2, 6])
        #expect(next.grid == state.grid)
        #expect(HintFinder.findHint(for: .validation, in: next) == nil)
    }

    @Test("A rule-in action matches only the same digit at the same cell")
    func ruleInEquality() {
        let action = HintAction(position: twoOptionCell, ruleIn: 6)
        #expect(action == HintAction(position: twoOptionCell, ruleIn: 6))
        #expect(action != HintAction(position: twoOptionCell, ruleIn: 2))
        #expect(action != HintAction(position: twoOptionCell, ruleOut: 6))
        #expect(action != HintAction(position: twoOptionCell, pencilIn: 6))
        #expect(Set([action, HintAction(position: twoOptionCell, ruleIn: 6)]).count == 1)
    }
}
