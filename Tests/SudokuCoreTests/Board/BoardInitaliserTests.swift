//
//  BoardInitaliserTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//
import Testing
@testable import SudokuCore

struct BoardInitialisationTests {

    @Test("Initialisation with Given Cells")
    @MainActor
    func initialisationWithGivenCells() {
        // When: a board is created with a valid 9x9 matrix
        let sampleGivenCells: [[Int]] = [
            [3,2,9, 0,8,4, 0,0,5],
            [0,0,4, 0,2,0, 7,0,8],
            [0,0,0, 0,0,0, 4,0,3],

            [0,1,0, 0,5,0, 0,0,9],
            [0,0,8, 4,0,0, 0,0,1],
            [7,3,0, 0,9,8, 0,0,2],

            [9,4,0, 8,0,5, 0,1,0],
            [0,0,0, 0,0,6, 3,5,0],
            [0,5,3, 0,0,7, 9,0,6]
        ]

        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )

        // Then: board properties should be set correctly
        #expect(board.difficulty == .easy)
        #expect(board.cells.count == 81)
        #expect(board.startingGrid == sampleGivenCells)

        // And: each cell is correctly initialised
        for (row, columns) in sampleGivenCells.enumerated() {
            for (col, value) in columns.enumerated() {
                let index = Puzzle.Index(row: row, column: col)
                let cell = board.cell(at: index)

                if value != 0 {
                    #expect(cell.value == value)
                    #expect(cell.isGiven == true)
                } else {
                    #expect(cell.value == nil)
                    #expect(cell.isGiven == false)
                }
            }
        }
    }

    @Test("Default Initializer Creates an Empty Board")
    @MainActor
    func defaultInitializerCreatesEmptyBoard() {
        // When: a board is created using the default initialiser
        let board = Board()

        // Then: the board should have a difficulty of .easy and contain 81 cells
        #expect(board.difficulty == .easy)
        #expect(board.cells.count == 81)

        // And: each cell should be empty (value is nil) and not marked as given
        for cell in board.cells {
            #expect(cell.value == nil)
            #expect(cell.isGiven == false)
        }
    }

    @Test("Convenience Initialiser with String Parses Puzzle Correctly")
    @MainActor
    func convenienceInitializerWithStringParsesPuzzleCorrectly() {
        // Given: an 81-digit puzzle string (where '0' indicates an empty cell)
        let puzzleString = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

        // When: a board is initialised with this string and a specific difficulty
        let board = Board(difficulty: .medium, string: puzzleString)

        // Then: the board should have the correct difficulty and 81 cells
        #expect(board.difficulty == .medium)
        #expect(board.cells.count == 81)

        // And: verify a couple of cells to ensure parsing is correct
        let firstCell = board.cell(at: Puzzle.Index(row: 0, column: 0))
        #expect(firstCell.value == 5)
        #expect(firstCell.isGiven == true)

        let emptyCell = board.cell(at: Puzzle.Index(row: 0, column: 2))
        #expect(emptyCell.value == nil)
        #expect(emptyCell.isGiven == false)


    }
}
