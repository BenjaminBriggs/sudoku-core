//
//  SudokuSolverTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//


import Testing
@testable import SudokuCore

struct SudokuSolverTests {
    // A valid, complete Sudoku grid
    let completeSudoku: [[Int]] = [
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
    
    // An easy puzzle with most cells filled in
    let easyPuzzle: [[Int]] = [
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
    
    // A harder puzzle with fewer givens
    let hardPuzzle: [[Int]] = [
        [0, 0, 0, 2, 0, 0, 0, 6, 3],
        [3, 0, 0, 0, 0, 5, 4, 0, 1],
        [0, 0, 1, 0, 0, 3, 9, 8, 0],
        [0, 0, 0, 0, 0, 0, 0, 9, 0],
        [0, 0, 0, 5, 3, 8, 0, 0, 0],
        [0, 3, 0, 0, 0, 0, 0, 0, 0],
        [0, 2, 6, 3, 0, 0, 5, 0, 0],
        [5, 0, 3, 7, 0, 0, 0, 0, 8],
        [4, 7, 0, 0, 0, 1, 0, 0, 0]
    ]
    
    // A malformed puzzle (not 9x9)
    let invalidPuzzle: [[Int]] = [
        [5, 3, 4, 6, 7, 8, 9, 1],
        [6, 7, 2, 1, 9, 5, 3, 4],
        [1, 9, 8, 3, 4, 2, 5, 6],
        [8, 5, 9, 7, 6, 1, 4, 2],
        [4, 2, 6, 8, 5, 3, 7, 9],
        [7, 1, 3, 9, 2, 4, 8, 5],
        [9, 6, 1, 5, 3, 7, 2, 8],
        [2, 8, 7, 4, 1, 9, 6, 3]
    ]
    
    // An unsolvable puzzle (with conflicts)
    let unsolvablePuzzle: [[Int]] = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 8, 0, 8, 0, 0, 7, 9]  // Duplicate 8 in row 8
    ]
    
    @Test("SudokuSolver correctly solves a complete Sudoku")
    func testSolveCompleteSudoku() {
        let (solution, callCount) = SudokuSolver.solve(grid: completeSudoku)

        #expect(solution != nil)
        #expect(solution == completeSudoku)
        #expect(callCount == 1)  // Only needs one call for a complete puzzle
    }
    
    @Test("SudokuSolver correctly solves an easy puzzle")
    func testSolveEasyPuzzle() {
        let (solution, callCount) = SudokuSolver.solve(grid: easyPuzzle)

        #expect(solution != nil)
        #expect(solution != easyPuzzle)  // Solution should be different from input
        #expect(try! Validator.isCompleteAndValidSolution(solution!))
        #expect(callCount >= 1)  // Should need multiple calls for an incomplete puzzle
        #expect(callCount < 50)  // But not too many for an easy puzzle
    }
    
    @Test("SudokuSolver correctly solves a hard puzzle")
    func testSolveHardPuzzle() {
        let (solution, callCount) = SudokuSolver.solve(grid: hardPuzzle)

        #expect(solution != nil)
        #expect(try! Validator.isCompleteAndValidSolution(solution!))
        #expect(callCount >= 10)  // Should need more calls for a hard puzzle
    }
    
    @Test("SudokuSolver correctly identifies an unsolvable puzzle")
    func testUnsolvablePuzzle() {
        let (solution, _) = SudokuSolver.solve(grid: unsolvablePuzzle)
        #expect(solution == nil)  // Should not find a solution
    }
}
