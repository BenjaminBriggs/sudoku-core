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
        #expect(callCount == 1)  // Nothing to fill: the search only looks once
    }

    @Test("SudokuSolver correctly solves an easy puzzle")
    func testSolveEasyPuzzle() {
        let (solution, callCount) = SudokuSolver.solve(grid: easyPuzzle)
        let emptySquares = easyPuzzle.joined().filter { $0 == 0 }.count

        #expect(solution != nil)
        #expect(solution != easyPuzzle)  // Solution should be different from input
        #expect(try! Validator.isCompleteAndValidSolution(solution!))
        // Singles all the way, so every square is filled once and the search never backs up
        #expect(callCount == emptySquares + 1)
    }

    @Test("SudokuSolver correctly solves a hard puzzle")
    func testSolveHardPuzzle() {
        let (solution, callCount) = SudokuSolver.solve(grid: hardPuzzle)
        let emptySquares = hardPuzzle.joined().filter { $0 == 0 }.count

        #expect(solution != nil)
        #expect(try! Validator.isCompleteAndValidSolution(solution!))
        #expect(callCount >= emptySquares + 1)  // At least one fill per empty square
    }

    @Test("SudokuSolver keeps the clues and finds each corpus puzzle's solution")
    func testSolvesTheCorpus() {
        for puzzle in CorpusPuzzle.fixtureCorpus {
            #expect(SudokuSolver.solve(grid: puzzle.startingState).solution == puzzle.solution)
        }
    }

    @Test("SudokuSolver gives the same one of several solutions every time")
    func testSeveralSolutions() throws {
        var sparse = easyPuzzle
        sparse[0] = Array(repeating: 0, count: 9)
        sparse[4] = Array(repeating: 0, count: 9)
        #expect(Validator.solutionCount(of: sparse).cappedCount == 2)

        let solution = try #require(SudokuSolver.solve(grid: sparse).solution)
        #expect(try Validator.isCompleteAndValidSolution(solution))
        for row in 0..<9 {
            for column in 0..<9 where sparse[row][column] != 0 {
                #expect(solution[row][column] == sparse[row][column])
            }
        }
        #expect(SudokuSolver.solve(grid: sparse).solution == solution)
    }

    @Test("SudokuSolver finds no solution for a grid that isn't 9×9 or holds a digit past 9")
    func testMalformedGrids() {
        #expect(SudokuSolver.solve(grid: invalidPuzzle).solution == nil)
        var outOfRange = easyPuzzle
        outOfRange[0][2] = 10
        #expect(SudokuSolver.solve(grid: outOfRange).solution == nil)
    }

    @Test("SudokuSolver correctly identifies an unsolvable puzzle")
    func testUnsolvablePuzzle() {
        let (solution, _) = SudokuSolver.solve(grid: unsolvablePuzzle)
        #expect(solution == nil)  // Should not find a solution
    }

    @Test("SudokuSolver finds no solution wherever a clue clashes with another")
    func testClashingClues() {
        let clashing = easyPuzzle.withEachClashingClue()
        #expect(clashing.isEmpty == false)
        #expect(clashing.filter { SudokuSolver.solve(grid: $0).solution != nil }.isEmpty)
    }

    @Test("A puzzle with no solution that only the search can rule out returns nil")
    func testUnsolvableAfterSearch() {
        // A unique puzzle with one empty cell given a digit its peers allow but the solution
        // doesn't have: it has no solution, which only the search finds.
        let grid = CorpusPuzzle.fixtureCorpus[0].unsolvableGrid
        #expect(SudokuSolver.solve(grid: grid).solution == nil)
    }
}
