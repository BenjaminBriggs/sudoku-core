//
//  SolutionAnalysisTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct SolutionAnalysisTests {
    /// A unique 30-clue puzzle (the classic Wikipedia example).
    let unique: [[Int]] = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ]

    let solved: [[Int]] = [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ]

    /// A 17-clue puzzle, which is minimal: no 16-clue sudoku has a unique solution.
    let minimal17: [[Int]] = Solution.cells(
        from: "000000010400000000020000000000050407008000300001090000300400200050100000000806000"
    )

    // MARK: - Solution count

    @Test func uniqueGridReturnsItsSolution() {
        #expect(Validator.solutionCount(of: unique) == .unique(solved))
        #expect(Validator.solutionCount(of: unique).cappedCount == 1)
    }

    @Test func solvedGridIsUnique() {
        #expect(Validator.solutionCount(of: solved) == .unique(solved))
    }

    @Test func emptyGridHasTwoDistinctValidSamples() throws {
        guard case .multiple(let first, let second) = Validator.solutionCount(of: .empty()) else {
            Issue.record("Expected several solutions")
            return
        }
        #expect(first != second)
        #expect(try Validator.isCompleteAndValidSolution(first))
        #expect(try Validator.isCompleteAndValidSolution(second))
    }

    @Test func samplesKeepTheClues() {
        var grid = unique
        grid[0][0] = 0
        grid[0][1] = 0
        grid[1][0] = 0
        let count = Validator.solutionCount(of: grid)
        guard case .multiple(let first, let second) = count else {
            // Removing three clues may still leave it unique; either way the clues must be kept.
            #expect(count.isUnique)
            return
        }
        for position in Puzzle.Index.allIndices where grid[position.row][position.column] != 0 {
            #expect(first[position.row][position.column] == grid[position.row][position.column])
            #expect(second[position.row][position.column] == grid[position.row][position.column])
        }
    }

    @Test func clashingCluesHaveNoSolution() {
        var grid = unique
        grid[0][2] = 5 // Repeats the 5 in row 0.
        #expect(Validator.solutionCount(of: grid) == .none)
        #expect(Validator.solutionCount(of: grid).cappedCount == 0)
    }

    @Test func unclashingButImpossibleCluesHaveNoSolution() {
        // Row 0 leaves only 9 for its last cell, but column 8 already has a 9.
        var grid = Solution.empty()
        grid[0] = [1, 2, 3, 4, 5, 6, 7, 8, 0]
        grid[5][8] = 9
        #expect(Validator.solutionCount(of: grid) == .none)
    }

    @Test func malformedGridHasNoSolution() {
        #expect(Validator.solutionCount(of: [[1, 2, 3]]) == .none)
    }

    @Test func agreesWithHasUniqueSolution() {
        let grids = [unique, minimal17, Solution.empty(), solved]
        for grid in grids {
            #expect(Validator.solutionCount(of: grid).isUnique == Validator.hasUniqueSolution(grid))
        }
    }

    // MARK: - Differing cells

    @Test func differingCellsListsMismatchesInRowMajorOrder() {
        var other = solved
        other[4][4] = 0
        other[0][8] = 0
        #expect(Validator.differingCells(solved, other) == [
            Puzzle.Index(row: 0, column: 8),
            Puzzle.Index(row: 4, column: 4),
        ])
        #expect(Validator.differingCells(solved, solved).isEmpty)
    }

    // MARK: - Minimality

    @Test func seventeenClueGridIsMinimal() {
        #expect(Validator.redundantClues(in: minimal17).isEmpty)
        #expect(Validator.isMinimal(minimal17))
    }

    @Test func solvedGridHasRedundantClues() {
        let redundant = Validator.redundantClues(in: solved)
        // Any single cell of a full grid follows from the rest.
        #expect(redundant.count == 81)
        #expect(Validator.isMinimal(solved) == false)
    }

    @Test func redundantCluesKeepUniquenessWhenRemoved() {
        let redundant = Validator.redundantClues(in: unique)
        #expect(redundant.isEmpty == false)
        for position in redundant {
            var reduced = unique
            reduced[position.row][position.column] = 0
            #expect(Validator.hasUniqueSolution(reduced))
        }
    }

    @Test func nonUniqueGridIsNeverMinimal() {
        #expect(Validator.redundantClues(in: .empty()).isEmpty)
        #expect(Validator.isMinimal(.empty()) == false)
    }

    // MARK: - Suggested clue

    @Test func suggestedClueFillsAnEmptyCellWithoutClashing() throws {
        // Taking a clue from a minimal grid leaves it with several solutions.
        var grid = minimal17
        grid[0][7] = 0
        let suggestion = try #require(Validator.suggestedClue(for: grid))
        #expect(grid[suggestion.position.row][suggestion.position.column] == 0)
        grid[suggestion.position.row][suggestion.position.column] = suggestion.value
        #expect(Validator.hasNoConflicts(in: grid))
        #expect(Validator.solutionCount(of: grid) != .none)
    }

    @Test func suggestedClueNarrowsTheSamples() throws {
        var grid = unique
        for column in 0..<9 { grid[0][column] = 0 }
        guard case .multiple(let first, let second) = Validator.solutionCount(of: grid) else {
            Issue.record("Expected several solutions")
            return
        }
        let before = Validator.differingCells(first, second)
        let suggestion = try #require(Validator.suggestedClue(for: grid))
        #expect(before.contains(suggestion.position))
        #expect([first, second].contains { $0[suggestion.position.row][suggestion.position.column] == suggestion.value })

        grid[suggestion.position.row][suggestion.position.column] = suggestion.value
        switch Validator.solutionCount(of: grid) {
        case .unique:
            break
        case .multiple(let a, let b):
            #expect(Validator.differingCells(a, b).count <= before.count)
        case .none:
            Issue.record("A clue from a real solution can't leave no solutions")
        }
    }

    @Test func noSuggestionForUniqueOrUnsolvableGrids() {
        #expect(Validator.suggestedClue(for: unique) == nil)
        var clashing = unique
        clashing[0][2] = 5
        #expect(Validator.suggestedClue(for: clashing) == nil)
    }

    @Test func repeatedSuggestionsReachAUniqueGrid() throws {
        var grid = Solution.empty()
        var added = 0
        while case .multiple = Validator.solutionCount(of: grid) {
            let suggestion = try #require(Validator.suggestedClue(for: grid))
            grid[suggestion.position.row][suggestion.position.column] = suggestion.value
            added += 1
            try #require(added <= 81)
        }
        #expect(Validator.solutionCount(of: grid).isUnique)
    }
}

struct GridSymmetryTests {
    @Test func partners() {
        let position = Puzzle.Index(row: 1, column: 2)
        #expect(GridSymmetry.rotational.partner(of: position) == Puzzle.Index(row: 7, column: 6))
        #expect(GridSymmetry.mirror.partner(of: position) == Puzzle.Index(row: 1, column: 6))
        #expect(GridSymmetry.diagonal.partner(of: position) == Puzzle.Index(row: 2, column: 1))
        let centre = Puzzle.Index(row: 4, column: 4)
        for symmetry in GridSymmetry.allCases {
            #expect(symmetry.partner(of: centre) == centre)
        }
    }

    @Test func partnerIsAnInvolution() {
        for symmetry in GridSymmetry.allCases {
            for position in Puzzle.Index.allIndices {
                #expect(symmetry.partner(of: symmetry.partner(of: position)) == position)
            }
        }
    }

    @Test func emptyAndFullGridsHaveEverySymmetry() {
        #expect(GridSymmetry.symmetries(of: .empty()) == GridSymmetry.allCases)
        let full = [[Int]](repeating: [Int](repeating: 1, count: 9), count: 9)
        #expect(GridSymmetry.symmetries(of: full) == GridSymmetry.allCases)
    }

    @Test func detectsOnlyTheSymmetryPresent() {
        var grid = Solution.empty()
        grid[0][1] = 3
        grid[8][7] = 4 // Its half-turn partner, a different digit: layout only.
        #expect(GridSymmetry.symmetries(of: grid) == [.rotational])

        var mirrored = Solution.empty()
        mirrored[2][0] = 1
        mirrored[2][8] = 2
        #expect(GridSymmetry.symmetries(of: mirrored) == [.mirror])

        var diagonal = Solution.empty()
        diagonal[0][3] = 1
        diagonal[3][0] = 2
        #expect(GridSymmetry.symmetries(of: diagonal) == [.diagonal])

        var none = Solution.empty()
        none[0][1] = 1
        #expect(GridSymmetry.symmetries(of: none).isEmpty)
    }
}
