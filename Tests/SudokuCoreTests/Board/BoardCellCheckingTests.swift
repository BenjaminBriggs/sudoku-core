//
//  BoardCellCheckingTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct BoardCellCheckingTests {

    // A complete valid sudoku grid.
    let sampleFullSolution: [[Int]] = [
        [5,3,4,6,7,8,9,1,2],
        [6,7,2,1,9,5,3,4,8],
        [1,9,8,3,4,2,5,6,7],
        [8,5,9,7,6,1,4,2,3],
        [4,2,6,8,5,3,7,9,1],
        [7,1,3,9,2,4,8,5,6],
        [9,6,1,5,3,7,2,8,4],
        [2,8,7,4,1,9,6,3,5],
        [3,4,5,2,8,6,1,7,9]
    ]

    // An empty 9x9 grid (all zeros) for tests.
    let emptyGrid: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)

    @Test("isValid returns true for a valid board and false for an invalid board")
    @MainActor
    func testIsValidProperty() {
        // Create a board with a full valid solution.
        let board = Board(
            difficulty: .easy,
            givenCells: sampleFullSolution,
            solution: sampleFullSolution
        )
        #expect(board.isValid == true)

        // Introduce a conflict by setting cell (0,0) to the same value as cell (0,1).
        let pos = Puzzle.Index(row: 0, column: 0)
        let linearIndex = pos.row * 9 + pos.column
        var modifiedCell = board.cells[linearIndex]
        modifiedCell.value = board.cell(at: Puzzle.Index(row: 0, column: 1)).value
        board.cells[linearIndex] = modifiedCell

        #expect(board.isValid == false)
    }
}
