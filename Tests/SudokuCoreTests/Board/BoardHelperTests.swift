//
//  BoardHelperTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct BoardHelperTests {

    // A sample 9x9 matrix for testing partial boards
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
    
    // A complete valid sudoku grid for testing validation helpers.
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

    @Test("cell(at:) returns correct cell")
    @MainActor
    func testCellAt() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 0, column: 1)
        let cell = board.cell(at: pos)
        #expect(cell.position.row == pos.row)
        #expect(cell.position.column == pos.column)
    }

    @Test("allHouses returns 9 unique houses each with 9 indices")
    @MainActor
    func testAllHouses() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let houses = board.allHouses
        #expect(houses.count == 9)
        for house in houses {
            #expect(house.count == 9)
        }
        // For a known position, ensure its house matches one of the houses in allHouses.
        let pos = Puzzle.Index(row: 0, column: 0)
        let expectedHouse = pos.houseIndices
        let found = houses.contains { Set($0) == Set(expectedHouse) }
        #expect(found == true)
    }

    @Test("commonHouse returns correct house for indices in the same house")
    @MainActor
    func testCommonHouseValid() {
        // Indices from the top-left house: (0,0), (1,1), (2,2)
        let indices = [
            Puzzle.Index(row: 0, column: 0),
            Puzzle.Index(row: 1, column: 1),
            Puzzle.Index(row: 2, column: 2)
        ]
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let common = board.commonHouse(for: indices)
        #expect(common != nil)
        if let common = common {
            #expect(common.count == 9)
            for idx in indices {
                #expect(common.contains(idx))
            }
        }
    }

    @Test("commonHouse returns nil for indices not in the same house")
    @MainActor
    func testCommonHouseInvalid() {
        // Indices from different houses: (0,0) and (0,3)
        let indices = [
            Puzzle.Index(row: 0, column: 0),
            Puzzle.Index(row: 0, column: 3)
        ]
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let common = board.commonHouse(for: indices)
        #expect(common == nil)
    }

    @Test("commonHouse returns nil for empty input")
    @MainActor
    func testCommonHouseEmpty() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let common = board.commonHouse(for: [])
        #expect(common == nil)
    }

    @Test("boxNumber returns correct numbers")
    @MainActor
    func testBoxNumber() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // (0,0) => (0/3)*3 + (0/3) + 1 = 1
        var pos = Puzzle.Index(row: 0, column: 0)
        #expect(board.boxNumber(for: pos) == 1)
        
        // (0,4) => (0/3)*3 + (4/3) + 1 = 0 + 1 + 1 = 2
        pos = Puzzle.Index(row: 0, column: 4)
        #expect(board.boxNumber(for: pos) == 2)
        
        // (4,4) => (4/3)*3 + (4/3) + 1 = (1*3)+(1)+1 = 5
        pos = Puzzle.Index(row: 4, column: 4)
        #expect(board.boxNumber(for: pos) == 5)
        
        // (8,8) => (8/3)*3 + (8/3) + 1 = (2*3)+(2)+1 = 9
        pos = Puzzle.Index(row: 8, column: 8)
        #expect(board.boxNumber(for: pos) == 9)
    }

    @Test("cellPositions(with:) returns correct indices for a given number")
    @MainActor
    func testCellPositionsWithNumber() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // In sampleGivenCells, the number 5 appears at (0,0), (1,5), and (7,8)
        let expectedPositions: Set<Puzzle.Index> = [
            Puzzle.Index(row: 0, column: 0),
            Puzzle.Index(row: 1, column: 5),
            Puzzle.Index(row: 7, column: 8)
        ]
        let positions = board.cellPositions(with: 5)
        #expect(positions == expectedPositions)
    }

    @Test("cellValid(at:) returns true for cells with nil value")
    @MainActor
    func testCellValidNilValue() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Select an empty cell, e.g., (0,2)
        let pos = Puzzle.Index(row: 0, column: 2)
        let cell = board.cell(at: pos)
        #expect(cell.value == nil)
        #expect(board.cellValid(at: cell) == true)
    }

    @Test("cellValid(at:) validates correct and incorrect values using full solution")
    @MainActor
    func testCellValidWithFullSolution() {
        // Create a board with a full solution
        let board = Board(
            difficulty: .easy,
            givenCells: sampleFullSolution,
            solution: sampleFullSolution
        )
        // Pick a cell that should be valid (e.g., (0,0) should be 5)
        let pos = Puzzle.Index(row: 0, column: 0)
        var cell = board.cell(at: pos)
        #expect(cell.value == 5)
        #expect(board.cellValid(at: cell) == true)
        
        // Now simulate an invalid value by modifying the cell's value.
        // Find the linear index for (0,0)
        let linearIndex = pos.row * 9 + pos.column
        var modifiedCell = board.cells[linearIndex]
        modifiedCell.value = 9  // Incorrect value compared to sampleFullSolution
        board.cells[linearIndex] = modifiedCell
        
        // Retrieve the updated cell and test validity.
        cell = board.cell(at: pos)
        #expect(board.cellValid(at: cell) == false)
    }

    @Test("cellComplete(at:) returns true when cell is in a completed row")
    @MainActor
    func testCellCompleteWithCompletedRow() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 0, column: 0)
        let cell = board.cell(at: pos)
        #expect(board.cellComplete(at: cell) == false)
        
        // Mark the row as completed.
        board.completedRows.insert(pos.row)
        #expect(board.cellComplete(at: cell) == true)
    }

    @Test("cellComplete(at:) returns true when cell's value is completed")
    @MainActor
    func testCellCompleteWithCompletedNumber() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        let pos = Puzzle.Index(row: 0, column: 0)
        let cell = board.cell(at: pos)
        #expect(cell.value == 5)
        #expect(board.cellComplete(at: cell) == false)
        
        // Mark the number 5 as completed.
        board.completedNumbers.insert(5)
        #expect(board.cellComplete(at: cell) == true)
    }

    @Test("cellComplete(at:) returns false when no completion criteria are met")
    @MainActor
    func testCellCompleteFalse() {
        let board = Board(
            difficulty: .easy,
            givenCells: sampleGivenCells,
            solution: nil
        )
        // Pick an empty cell, e.g., (2,0)
        let pos = Puzzle.Index(row: 2, column: 0)
        let cell = board.cell(at: pos)
        #expect(board.cellComplete(at: cell) == false)
    }
}
