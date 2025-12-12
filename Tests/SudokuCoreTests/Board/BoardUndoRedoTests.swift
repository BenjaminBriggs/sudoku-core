//
//  BoardUndoRedoTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct BoardUndoRedoTests {

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

    @Test("undo() reverts a marking change")
    @MainActor
    func testUndoRevertsChange() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Choose a cell that is not given. In sample, (1,2) is empty.
        let index = Puzzle.Index(row: 1, column: 2)
        #expect(board.cell(at: index).value == nil)
        
        // Mark cell (1,2) as 8. mark(positions:as:) automatically saves state.
        board.mark(positions: [index], as: 8)
        #expect(board.cell(at: index).value == 8)
        
        // Undo the change.
        board.undo()
        #expect(board.cell(at: index).value == nil)
    }

    @Test("Multiple undo/redo operations restore correct board state")
    @MainActor
    func testMultipleUndoRedo() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Choose two cells (both initially empty).
        let indexA = Puzzle.Index(row: 1, column: 2)
        let indexB = Puzzle.Index(row: 2, column: 3)
        #expect(board.cell(at: indexA).value == nil)
        #expect(board.cell(at: indexB).value == nil)
        
        // Mark indexA as 7.
        board.mark(positions: [indexA], as: 7)
        #expect(board.cell(at: indexA).value == 7)
        
        // Mark indexB as 3.
        board.mark(positions: [indexB], as: 3)
        #expect(board.cell(at: indexB).value == 3)
        
        // First undo: should revert the change at indexB while indexA remains 7.
        board.undo()
        #expect(board.cell(at: indexB).value == nil)
        #expect(board.cell(at: indexA).value == 7)
        
        // Second undo: should revert the change at indexA.
        board.undo()
        #expect(board.cell(at: indexA).value == nil)
    }

    @Test("saveState does not append duplicate state")
    @MainActor
    func testSaveStateDoesNotDuplicate() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Initially, the undo stack should be empty.
        #expect(board.undoStack.count == 0)
        
        // Call saveState once; a state is saved.
        board.saveState()
        #expect(board.undoStack.count == 1)
        
        // Call saveState again without any changes; undoStack should not increase.
        board.saveState()
        #expect(board.undoStack.count == 1)
        
        // Make a change by marking a cell.
        let index = Puzzle.Index(row: 2, column: 5)
        board.mark(positions: [index], as: 8)
        // The stack should still be 1 until the next save
        #expect(board.undoStack.count == 1)

        // Now, undoStack should have increased.
        board.saveState()
        #expect(board.undoStack.count > 1)
    }

    @Test("undo(to:) reverts board to a specific previous state")
    @MainActor
    func testUndoToSpecificStep() throws {
        // Create a board.
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )

        // Mark a non-given cell (at (1,1)) with 7.
        let index1 = Puzzle.Index(row: 1, column: 1)
        board.mark(positions: [index1], as: 7)

        // Save this state as the target step.
        let targetStep = Board.UndoStep(
            cells: board.cells,
            changes: [],
            isValid: board.isValid,
            correctSolution: false
        )

        // Mark another cell (at (1,2)) with 8.
        let index2 = Puzzle.Index(row: 1, column: 2)
        board.mark(positions: [index2], as: 8)
        #expect(board.cell(at: index2).value == 8)

        // Now, undo to the target step.
        try board.undo(to: targetStep)

        // Verify that the board's state matches the target state.
        #expect(board.cells == targetStep.cells)
    }
}
