//
//  BoardMarkingTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct BoardMarkingTests {

    // A sample 9x9 matrix for testing.
    let sampleGivenCells: [[Int]] = [
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

    // MARK: - mark(positions:as:)

    @Test("mark(positions:as:) sets value for non-given cells and ignores given cells")
    @MainActor
    func testMark() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // For a non-given cell (0,2) — it should initially be empty.
        let posEmpty = Puzzle.Index(row: 0, column: 2)
        board.mark(positions: [posEmpty], as: 9)
        let cellEmpty = board.cell(at: posEmpty)
        #expect(cellEmpty.value == 9)
        
        // For a given cell (0,0) with value 5, mark should leave the value unchanged.
        let posGiven = Puzzle.Index(row: 0, column: 0)
        board.mark(positions: [posGiven], as: 8)
        let cellGiven = board.cell(at: posGiven)
        #expect(cellGiven.value == 5)
    }

    // MARK: - clearCell(at:)

    @Test("clearCell(at:) clears value, pencil marks, advanced pencil marks, ruled out candidates and resets background")
    @MainActor
    func testClearCell() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Use a non-given cell, for example (0,2).
        let pos = Puzzle.Index(row: 0, column: 2)
        // First, assign a value and add some marks.
        board.mark(positions: [pos], as: 7)
        board.cells[pos.linerIndex].simplePencilMarks = [1, 2]
        board.cells[pos.linerIndex].advancedPencilMarks = [3, 4]
        board.cells[pos.linerIndex].ruledOutCandidates = [5]
        board.cells[pos.linerIndex].background = Board.Cell.Background(from: 2)
        
        board.clearCell(at: [pos])
        let cell = board.cell(at: pos)
        #expect(cell.value == nil)
        #expect(cell.simplePencilMarks.isEmpty == true)
        #expect(cell.advancedPencilMarks.isEmpty == true)
        #expect(cell.ruledOutCandidates.isEmpty == true)
        #expect(cell.background == .clear)
    }

    // MARK: - pencil(positions:as:)

    @Test("pencil(positions:as:) toggles simple pencil marks")
    @MainActor
    func testPencil() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 1, column: 2)
        // Initially, the cell should not have the pencil mark.
        board.pencil(positions: [pos], as: 3)
        let cellAfterInsert = board.cell(at: pos)
        #expect(cellAfterInsert.simplePencilMarks.contains(3))
        
        // Calling pencil again should remove the pencil mark.
        board.pencil(positions: [pos], as: 3)
        let cellAfterToggle = board.cell(at: pos)
        #expect(cellAfterToggle.simplePencilMarks.contains(3) == false)
    }

    // MARK: - advancedPencil(positions:as:)

    @Test("advancedPencil(positions:as:) toggles advanced pencil marks")
    @MainActor
    func testAdvancedPencil() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 2, column: 3)
        board.advancedPencil(positions: [pos], as: 6)
        let cellAfterInsert = board.cell(at: pos)
        #expect(cellAfterInsert.advancedPencilMarks.contains(6))
        
        // Toggle off.
        board.advancedPencil(positions: [pos], as: 6)
        let cellAfterToggle = board.cell(at: pos)
        #expect(cellAfterToggle.advancedPencilMarks.contains(6) == false)
    }

    // MARK: - color(positions:as:)

    @Test("color(positions:as:) toggles cell background")
    @MainActor
    func testColor() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 3, column: 4)
        let newColor = Board.Cell.Background(from: 4)
        board.color(positions: [pos], as: newColor)
        let cellAfterColor = board.cell(at: pos)
        #expect(cellAfterColor.background == newColor)
        
        // Applying the same color again should reset the background to .clear.
        board.color(positions: [pos], as: newColor)
        let cellAfterToggle = board.cell(at: pos)
        #expect(cellAfterToggle.background == .clear)
    }

    @Test("color(positions:as:) can be undone")
    @MainActor
    func testColorUndo() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 3, column: 4)
        let newColor = Board.Cell.Background(from: 4)
        board.color(positions: [pos], as: newColor)
        #expect(board.cell(at: pos).background == newColor)

        board.undo()
        #expect(board.cell(at: pos).background == .clear)
    }

    // MARK: - apply(hint:)

    @Test("apply(hint:) with multiple actions is undone in a single step")
    @MainActor
    func testApplyHintAtomicUndo() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let solvePos = Puzzle.Index(row: 0, column: 2)
        let ruleOutPos = Puzzle.Index(row: 1, column: 1)
        // Seed a pencil mark so the ruleOut action changes state too.
        board.pencil(positions: [ruleOutPos], as: 4)
        let cellsBeforeHint = board.cells

        let hint = HintStep(
            actions: [
                HintAction(position: solvePos, solveAs: 9),
                HintAction(position: ruleOutPos, ruleOut: 4),
            ],
            technique: .nakedSingle
        )
        board.apply(hint: hint)
        #expect(board.cells != cellsBeforeHint)

        board.undo()
        #expect(board.cells == cellsBeforeHint)
    }
}
