//
//  BoardStateRestorationTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//
import Testing
@testable import SudokuCore

struct BoardStateRestorationTests {
    // A sample state with some nonzero values.
    let testCurrentState: [[Int]] = [
        [5, 0, 0, 0, 7, 0, 0, 0, 3],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9]
    ]

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

    // Create a 9x9 matrix of empty sets, except cell (1,1) gets [2,4]
    var testSimplePencilMarks: [[Set<Int>]] {
        var array = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        array[1][1] = [2, 4]
        return array
    }
    
    // Create a 9x9 matrix of empty sets, except cell (2,2) gets [3,5]
    var testAdvancedPencilMarks: [[Set<Int>]] {
        var array = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        array[2][2] = [3, 5]
        return array
    }
    
    // Create a 9x9 matrix of zeros for background colors, except cell (3,3) gets 7.
    var testBackgroundColors: [[Int]] {
        var array = Array(repeating: Array(repeating: 9, count: 9), count: 9)
        array[3][3] = 7
        return array
    }
    
    @Test("restore() updates grid and computed properties correctly")
    @MainActor
    func testRestoreState() {
        // Create a board with an empty starting state.
        let board = Board(
            difficulty: .easy,
            givenCells: .empty(),
            solution: nil
        )
        
        // Restore the board state using our test matrices.
        board.restore(
            currentState: testCurrentState,
            simplePencilMarks: testSimplePencilMarks,
            advancedPencilMarks: testAdvancedPencilMarks,
            backgroundColors: testBackgroundColors,
            ruledOutCandidates: [],
            undoStack: [],
            solution: [],
            hintsUsed: 0,
            incorrectMoves: 0
        )
        
        // The grid computed property should match the testCurrentState.
        #expect(board.currentGrid == testCurrentState)

        // The simplePencilMarks computed property should match our testSimplePencilMarks.
        #expect(board.simplePencilMarks == testSimplePencilMarks)
        
        // The advancedPencilMarks computed property should match our testAdvancedPencilMarks.
        #expect(board.advancedPencilMarks == testAdvancedPencilMarks)
        
        // The backgroundColors computed property should match our testBackgroundColors.
        #expect(board.backgroundColors == testBackgroundColors)
    }

    @Test("resetToInitialState clears all user modifications while preserving givens")
    @MainActor
    func testResetToInitialState() {
        let board = Board(
            difficulty: .medium,
            givenCells: sampleGivenCells,
            solution: nil
        )

        // Simulate modifications on non-given cells.
        // (0,2) is non-given because sampleGivenCells[0][2] == 0.
        let modIndex = Puzzle.Index(row: 0, column: 2)
        board.cells[modIndex.linerIndex].value = 9
        board.cells[modIndex.linerIndex].simplePencilMarks = [1, 2]
        board.cells[modIndex.linerIndex].advancedPencilMarks = [3, 4]
        board.cells[modIndex.linerIndex].background = Board.Cell.Background(from: 5)

        // Modify another non-given cell, e.g., (1,1)
        let modIndex2 = Puzzle.Index(row: 1, column: 1)
        board.cells[modIndex2.linerIndex].value = 7
        board.cells[modIndex2.linerIndex].simplePencilMarks = [8]
        board.cells[modIndex2.linerIndex].advancedPencilMarks = [9]
        board.cells[modIndex2.linerIndex].background = Board.Cell.Background(from: 2)

        // Ensure a given cell remains unchanged.
        let givenIndex = Puzzle.Index(row: 0, column: 0) // sampleGivenCells[0][0] == 5 (given)
        #expect(board.cell(at: givenIndex).value == 5)

        // Call resetToInitialState.
        board.resetToInitialState()

        // After resetting, for each cell:
        // - If it is given, its value remains unchanged.
        // - If not given, its value is cleared (nil), no pencil marks, and background is .clear.
        for cell in board.cells {
            if cell.isGiven {
                #expect(cell.value != nil)
            } else {
                #expect(cell.value == nil)
                #expect(cell.simplePencilMarks.isEmpty)
                #expect(cell.advancedPencilMarks.isEmpty)
                #expect(cell.background == .clear)
            }
        }
    }
}
