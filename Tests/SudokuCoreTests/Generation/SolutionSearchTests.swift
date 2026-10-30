//
//  SolutionSearchTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct SolutionSearchTests {
    /// A unique 30-clue puzzle (the classic Wikipedia example).
    let unique: [[Int]] = Solution.cells(
        from: "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    )

    // MARK: - Counting

    @Test func uniqueGridCountsOne() {
        #expect(Validator.countSolutions(of: unique, limit: 10) == 1)
    }

    @Test func countStopsAtTheLimit() {
        #expect(Validator.countSolutions(of: .empty(), limit: 5) == 5)
        #expect(Validator.countSolutions(of: .empty(), limit: 64) == 64)
    }

    @Test func clashingCluesCountZero() {
        var grid = unique
        grid[0][2] = 5 // Repeats the 5 in row 0.
        #expect(Validator.countSolutions(of: grid, limit: 10) == 0)
    }

    @Test func zeroLimitCountsNothing() {
        #expect(Validator.countSolutions(of: unique, limit: 0) == 0)
    }

    @Test func countAgreesWithSolutionCount() {
        var grid = unique
        for position in [Puzzle.Index(row: 0, column: 0), Puzzle.Index(row: 4, column: 4), Puzzle.Index(row: 8, column: 8)] {
            grid[position.row][position.column] = 0
        }
        let capped = min(Validator.countSolutions(of: grid, limit: 2), 2)
        #expect(capped == Validator.solutionCount(of: grid).cappedCount)
    }

    // MARK: - Feasibility

    @Test func feasibleGridHasASolution() {
        #expect(Validator.hasSolution(unique, nodeLimit: 1_000) == true)
    }

    @Test func clashingGridHasNoSolution() {
        var grid = unique
        grid[0][2] = 5
        #expect(Validator.hasSolution(grid, nodeLimit: 1_000) == false)
    }

    @Test func runningOutOfNodesIsUnknown() {
        #expect(Validator.hasSolution(.empty(), nodeLimit: 1) == nil)
    }

    // MARK: - Random solutions

    @Test func randomSolutionKeepsTheCluesAndIsValid() throws {
        var grid = unique
        grid[0][0] = 0
        grid[1][0] = 0
        var generator = SearchRandom(seed: 7)
        let solution = try #require(Validator.randomSolution(of: grid, using: &generator))
        #expect(try Validator.isCompleteAndValidSolution(solution))
        for position in Puzzle.Index.allIndices where grid[position.row][position.column] != 0 {
            #expect(solution[position.row][position.column] == grid[position.row][position.column])
        }
    }

    @Test func sameSeedSameSolution() {
        var first = SearchRandom(seed: 42)
        var second = SearchRandom(seed: 42)
        #expect(Validator.randomSolution(of: .empty(), using: &first) == Validator.randomSolution(of: .empty(), using: &second))
    }

    @Test func differentSeedsVary() {
        let solutions = Set((0..<5).compactMap { seed -> [[Int]]? in
            var generator = SearchRandom(seed: UInt64(seed))
            return Validator.randomSolution(of: .empty(), using: &generator)
        })
        #expect(solutions.count > 1)
    }

    @Test func noRandomSolutionForClashingClues() {
        var grid = unique
        grid[0][2] = 5
        var generator = SearchRandom(seed: 1)
        #expect(Validator.randomSolution(of: grid, using: &generator) == nil)
    }
}
