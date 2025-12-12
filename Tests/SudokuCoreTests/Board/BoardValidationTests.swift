//
//  BoardValidationTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct BoardValidationTests {
    // A sample incomplete grid (zeros represent empty cells)
    let sampleIncomplete: [[Int]] = [
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
    
    // A complete valid sudoku grid.
    let sampleComplete: [[Int]] = [
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
    
    @Test("autoPencilAllCells sets simplePencilMarks to allowedValues for each cell")
    @MainActor
    func testAutoPencilAllCells() {
        // Create a board from an incomplete grid.
        let board = Board(
            difficulty: .easy,
            givenCells: sampleIncomplete,
            solution: nil
        )
        // First update cell validation to set validOptions.
        board.updateCellValidation()
        // Then manually call autoPencilAllCells().
        board.updatePencilMarks()
        
        for cell in board.cells {
            let expectedAllowed = cell.validOptions.subtracting(cell.ruledOutCandidates)
            #expect(cell.simplePencilMarks == expectedAllowed)
        }
    }
    
    @Test("updateCompletedSets computes completed sets for a complete board")
    @MainActor
    func testUpdateCompletedSetsCompleteBoard() {
        // Create a board with a complete sudoku grid.
        let board = Board(
            difficulty: .easy,
            givenCells: sampleComplete,
            solution: sampleComplete
        )
        board.updateCompletedSets()
        
        // For a complete board, every row, column, and house should be complete.
        let allRows = Set(0..<9)
        let allCols = Set(0..<9)
        let allHouses = Set(0..<9)
        let allDigits = Set(1...9)
        
        #expect(board.completedRows == allRows)
        #expect(board.completedColumns == allCols)
        #expect(board.completedHouses == allHouses)
        #expect(board.completedNumbers == allDigits)
        #expect(board.isSolved == true)
    }
    
    @Test("updateCompletedSets computes completed sets for an incomplete board")
    @MainActor
    func testUpdateCompletedSetsIncompleteBoard() {
        // Create a board with an incomplete grid.
        let board = Board(
            difficulty: .easy,
            givenCells: sampleIncomplete,
            solution: nil
        )
        board.updateCompletedSets()
        
        // In an incomplete board, not all rows, columns, houses, or digits are complete.
        #expect(board.completedRows.count < 9)
        #expect(board.completedColumns.count < 9)
        #expect(board.completedHouses.count < 9)
        #expect(board.completedNumbers.count < 9)
        #expect(board.isSolved == false)
    }
}
