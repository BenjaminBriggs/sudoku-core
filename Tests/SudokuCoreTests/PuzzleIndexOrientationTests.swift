//
//  PuzzleIndexOrientationTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct PuzzleIndexOrientationTests {

    // MARK: - cells(in:) Tests

    @Test("cells(in: .row) returns all indices with same row")
    func testCellsInRow() {
        let index = Puzzle.Index(row: 4, column: 3)
        let rowCells = index.cells(in: .row)
        var expected: Set<Puzzle.Index> = []
        for col in 0..<9 {
            expected.insert(Puzzle.Index(row: 4, column: col))
        }
        #expect(rowCells == expected)
    }

    @Test("cells(in: .column) returns all indices with same column")
    func testCellsInColumn() {
        let index = Puzzle.Index(row: 4, column: 3)
        let colCells = index.cells(in: .column)
        var expected: Set<Puzzle.Index> = []
        for row in 0..<9 {
            expected.insert(Puzzle.Index(row: row, column: 3))
        }
        #expect(colCells == expected)
    }

    @Test("cells(in: .house) returns all indices in the 3x3 block")
    func testCellsInHouseOrientation() {
        let index = Puzzle.Index(row: 4, column: 4)
        // Expected set is the same as index.houseIndices
        let expected = Set(index.houseIndices)
        let houseCells = index.cells(in: .house)
        #expect(houseCells == expected)
    }

    // MARK: - houseNumber Tests

    @Test("houseNumber returns 0 for index (0,0)")
    func testHouseNumberForTopLeft() {
        let index = Puzzle.Index(row: 0, column: 0)
        #expect(index.houseNumber == 0)
    }

    @Test("houseNumber returns 1 for index (0,4)")
    func testHouseNumberForTopMiddle() {
        let index = Puzzle.Index(row: 0, column: 4)
        #expect(index.houseNumber == 1)
    }

    @Test("houseNumber returns 4 for index (4,4)")
    func testHouseNumberForCenter() {
        let index = Puzzle.Index(row: 4, column: 4)
        #expect(index.houseNumber == 4)
    }

    @Test("houseNumber returns 8 for index (8,8)")
    func testHouseNumberForBottomRight() {
        let index = Puzzle.Index(row: 8, column: 8)
        #expect(index.houseNumber == 8)
    }

    // MARK: - houseIndices Tests

    @Test("houseIndices returns correct indices for index in center house")
    func testHouseIndicesForCenter() {
        let index = Puzzle.Index(row: 4, column: 4)
        let expected: Set<Puzzle.Index> = [
            Puzzle.Index(row: 3, column: 3), Puzzle.Index(row: 3, column: 4), Puzzle.Index(row: 3, column: 5),
            Puzzle.Index(row: 4, column: 3), Puzzle.Index(row: 4, column: 4), Puzzle.Index(row: 4, column: 5),
            Puzzle.Index(row: 5, column: 3), Puzzle.Index(row: 5, column: 4), Puzzle.Index(row: 5, column: 5)
        ]
        #expect(Set(index.houseIndices) == expected)
    }

    // MARK: - cellsInHouse(_:) Tests

    @Test("cellsInHouse returns correct indices for house 0 (top-left block)")
    func testCellsInHouseZero() {
        let expected: Set<Puzzle.Index> = [
            Puzzle.Index(row: 0, column: 0), Puzzle.Index(row: 0, column: 1), Puzzle.Index(row: 0, column: 2),
            Puzzle.Index(row: 1, column: 0), Puzzle.Index(row: 1, column: 1), Puzzle.Index(row: 1, column: 2),
            Puzzle.Index(row: 2, column: 0), Puzzle.Index(row: 2, column: 1), Puzzle.Index(row: 2, column: 2)
        ]
        let house0 = Set(Puzzle.Index.cellsInHouse(0))
        #expect(house0 == expected)
    }

    @Test("cellsInHouse returns correct indices for house 4 (center block)")
    func testCellsInHouseFour() {
        let expected: Set<Puzzle.Index> = [
            Puzzle.Index(row: 3, column: 3), Puzzle.Index(row: 3, column: 4), Puzzle.Index(row: 3, column: 5),
            Puzzle.Index(row: 4, column: 3), Puzzle.Index(row: 4, column: 4), Puzzle.Index(row: 4, column: 5),
            Puzzle.Index(row: 5, column: 3), Puzzle.Index(row: 5, column: 4), Puzzle.Index(row: 5, column: 5)
        ]
        let house4 = Set(Puzzle.Index.cellsInHouse(4))
        #expect(house4 == expected)
    }

    @Test("cellsInHouse returns correct indices for house 8 (bottom-right block)")
    func testCellsInHouseEight() {
        let expected: Set<Puzzle.Index> = [
            Puzzle.Index(row: 6, column: 6), Puzzle.Index(row: 6, column: 7), Puzzle.Index(row: 6, column: 8),
            Puzzle.Index(row: 7, column: 6), Puzzle.Index(row: 7, column: 7), Puzzle.Index(row: 7, column: 8),
            Puzzle.Index(row: 8, column: 6), Puzzle.Index(row: 8, column: 7), Puzzle.Index(row: 8, column: 8)
        ]
        let house8 = Set(Puzzle.Index.cellsInHouse(8))
        #expect(house8 == expected)
    }
}