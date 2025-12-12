//
//  ValidatorTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//
import Foundation
import Testing
@testable import SudokuCore

struct ValidatorTests {
    // A known complete, valid Sudoku grid.
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

    // An incomplete grid (with some zeros)
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

    // A grid with a conflict: duplicate in row 0.
    var sampleConflict: [[Int]] {
        var grid = sampleComplete
        grid[0][1] = 5 // duplicate 5 in first row (positions (0,0) and (0,1))
        return grid
    }

    // A nearly complete puzzle with one empty cell (cell at (0,0) set to 0) from sampleComplete.
    var nearlyComplete: [[Int]] {
        var grid = sampleComplete
        grid[0][0] = 0
        return grid
    }

    // An empty grid (all zeros)
    let emptyGrid: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)

    // MARK: - isValid tests

    @Test("isValid returns false when number is zero")
    func testIsValidZero() {
        let result = Validator.isValid(0, row: 0, column: 0, in: sampleComplete)
        #expect(result == false)
    }

    @Test("isValid returns true when placing the same number in its own cell on a complete board")
    func testIsValidForSameNumber() {
        // For a complete valid grid, placing the same number back should be valid.
        // For cell (0,0) with value 5.
        let result = Validator.isValid(5, row: 0, column: 0, in: sampleComplete)
        #expect(result == true)
    }

    @Test("isValid returns false when placing a conflicting number")
    func testIsValidForConflict() {
        // For cell (0,0) in a complete grid, try placing 3 (which appears elsewhere in row 0)
        let result = Validator.isValid(3, row: 0, column: 0, in: sampleComplete)
        #expect(result == false)
    }

    // MARK: - isCompleteAndValidSolution tests

    @Test("isCompleteAndValidSolution returns true for a complete valid grid")
    func testIsCompleteAndValidSolutionTrue() throws {
        let result = try Validator.isCompleteAndValidSolution(sampleComplete)
        #expect(result == true)
    }

    @Test("isCompleteAndValidSolution returns false for an incomplete grid")
    func testIsCompleteAndValidSolutionIncomplete() throws {
        let result = try Validator.isCompleteAndValidSolution(sampleIncomplete)
        #expect(result == false)
    }

    @Test("isCompleteAndValidSolution returns false for a complete grid with conflicts")
    func testIsCompleteAndValidSolutionConflict() throws {
        let result = try Validator.isCompleteAndValidSolution(sampleConflict)
        #expect(result == false)
    }

    // MARK: - hasNoConflicts tests

    @Test("hasNoConflicts returns true for a valid complete grid")
    func testHasNoConflictsTrue() {
        let result = Validator.hasNoConflicts(in: sampleComplete)
        #expect(result == true)
    }

    @Test("hasNoConflicts returns false for a grid with duplicate in a row")
    func testHasNoConflictsDuplicateRow() {
        let result = Validator.hasNoConflicts(in: sampleConflict)
        #expect(result == false)
    }

    // Negative tests for grid dimensions:

    @Test("hasNoConflicts returns false for a grid with less than 9 rows")
    func testHasNoConflictsInvalidRowCount() {
        var invalidGrid = sampleComplete
        invalidGrid.removeLast() // Now 8 rows instead of 9
        let result = Validator.hasNoConflicts(in: invalidGrid)
        #expect(result == false)
    }

    @Test("hasNoConflicts returns false for a grid with a row with less than 9 columns")
    func testHasNoConflictsInvalidColumnCount() {
        var invalidGrid = sampleComplete
        invalidGrid[0].removeLast() // First row now has 8 columns
        let result = Validator.hasNoConflicts(in: invalidGrid)
        #expect(result == false)
    }

    @Test("isCompleteAndValidSolution returns false for grid with invalid dimensions")
    func testIsCompleteAndValidSolutionInvalidDimensions() {
        var invalidGrid = sampleComplete
        invalidGrid.removeLast() // 8 rows
        #expect(throws: SudokuValidationError.invalidGridSize, performing: {
            _ = try Validator.isCompleteAndValidSolution(invalidGrid)
        })
    }

    // MARK: - hasUniqueSolution tests

    @Test("hasUniqueSolution returns true for a nearly complete puzzle with a unique solution")
    func testHasUniqueSolutionUnique() {
        let result = Validator.hasUniqueSolution(nearlyComplete)
        #expect(result == true)
    }

    @Test("hasUniqueSolution returns false for an empty puzzle with many solutions")
    func testHasUniqueSolutionEmpty() {
        let result = Validator.hasUniqueSolution(emptyGrid)
        #expect(result == false)
    }

    // Negative test for unsolvable puzzle:
    @Test("hasUniqueSolution returns false for an unsolvable puzzle")
    func testHasUniqueSolutionUnsolvable() {
        // Create an unsolvable puzzle by introducing a conflict into an incomplete grid.
        var unsolvable = sampleIncomplete
        // Introduce a conflict: duplicate a number in the first row.
        unsolvable[0][2] = 3  // Now row 0 has [5, 3, 3, ...]
        let result = Validator.hasUniqueSolution(unsolvable)
        #expect(result == false)
    }
}
