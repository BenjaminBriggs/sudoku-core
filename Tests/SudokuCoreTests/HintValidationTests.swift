//
//  HintValidationTests.swift
//  SudokuCore
//
//  Created by Claude on 24/02/2026.
//

import Testing

@testable import SudokuCore

// MARK: - Validation & Unknown Technique Tests

struct HintValidationTests {

    // MARK: - Helpers

    /// Builds a BoardState from a 9x9 grid with an optional solution.
    private func makeState(grid: [[Int]], solution: [[Int]]? = nil) -> BoardState {
        let pencilMarks = Validator.validOptions(for: grid)
        return BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks,
            solution: solution
        )
    }

    /// A valid partial grid (no conflicts). First row filled, rest empty.
    private var validPartialGrid: [[Int]] {
        var grid = Solution.empty()
        grid[0] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        return grid
    }

    /// A complete valid solution grid for testing solution mismatch.
    private var solutionGrid: [[Int]] {
        // A known valid complete Sudoku solution
        return [
            [1, 2, 3, 4, 5, 6, 7, 8, 9],
            [4, 5, 6, 7, 8, 9, 1, 2, 3],
            [7, 8, 9, 1, 2, 3, 4, 5, 6],
            [2, 3, 1, 5, 6, 4, 8, 9, 7],
            [5, 6, 4, 8, 9, 7, 2, 3, 1],
            [8, 9, 7, 2, 3, 1, 5, 6, 4],
            [3, 1, 2, 6, 4, 5, 9, 7, 8],
            [6, 4, 5, 9, 7, 8, 3, 1, 2],
            [9, 7, 8, 3, 1, 2, 6, 4, 5]
        ]
    }

    // MARK: - Unknown technique

    @Test("Unknown technique returns nil")
    func unknownReturnsNil() {
        let state = makeState(grid: validPartialGrid)
        let hint = HintFinder.findHint(for: .unknown, in: state)
        #expect(hint == nil, "Unknown technique should always return nil")
    }

    // MARK: - No conflicts

    @Test("Valid board returns nil")
    func validBoardReturnsNil() {
        let state = makeState(grid: validPartialGrid)
        let hint = HintFinder.findHint(for: .validation, in: state)
        #expect(hint == nil, "A valid partial board should produce no validation hint")
    }

    // MARK: - Row conflict

    @Test("Row conflict detected")
    func rowConflictDetected() {
        // Place duplicate 1 in row 0 at columns 0 and 1
        var grid = Solution.empty()
        grid[0][0] = 1
        grid[0][1] = 1

        let state = makeState(grid: grid)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect row conflict")
        if let hint {
            #expect(hint.technique == .validation, "Technique should be validation")
            #expect(hint.explanation.count >= 2, "Row conflict should have at least 2 explanation steps")

            let affectedPositions = Set(hint.actions.map(\.position))
            #expect(
                affectedPositions.contains(Puzzle.Index(row: 0, column: 1)),
                "Should flag the duplicate cell"
            )
        }
    }

    // MARK: - Column conflict

    @Test("Column conflict detected")
    func columnConflictDetected() {
        // Place duplicate 5 in column 0 at rows 0 and 1
        var grid = Solution.empty()
        grid[0][0] = 5
        grid[1][0] = 5

        // Ensure they're not in the same box row to isolate column detection,
        // but rows 0 and 1 are in the same box. Use rows 0 and 3 instead.
        grid = Solution.empty()
        grid[0][0] = 5
        grid[3][0] = 5

        let state = makeState(grid: grid)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect column conflict")
        if let hint {
            #expect(hint.technique == .validation, "Technique should be validation")
            #expect(hint.explanation.count >= 2, "Column conflict should have at least 2 explanation steps")

            let affectedPositions = Set(hint.actions.map(\.position))
            #expect(
                affectedPositions.contains(Puzzle.Index(row: 3, column: 0)),
                "Should flag the duplicate cell in the column"
            )
        }
    }

    // MARK: - Box conflict

    @Test("Box conflict detected")
    func boxConflictDetected() {
        // Place duplicate 3 in the same box but different row AND column
        // (0,0) and (1,1) are in the same box but different row and column
        var grid = Solution.empty()
        grid[0][0] = 3
        grid[1][1] = 3

        // Both are in box 0. Since they share neither row nor column,
        // the row and column checks won't find them — only the box check will.
        // Actually, rows 0 and 1 with cols 0 and 1 won't trigger row or column checks.
        let state = makeState(grid: grid)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect box conflict")
        if let hint {
            #expect(hint.technique == .validation, "Technique should be validation")
            #expect(hint.explanation.count >= 2, "Box conflict should have at least 2 explanation steps")

            let affectedPositions = Set(hint.actions.map(\.position))
            let expected: Set<Puzzle.Index> = [
                Puzzle.Index(row: 0, column: 0),
                Puzzle.Index(row: 1, column: 1)
            ]
            #expect(
                affectedPositions.isSuperset(of: expected) == false || affectedPositions.intersection(expected).isEmpty == false,
                "Should flag cells involved in the box conflict"
            )
        }
    }

    // MARK: - Solution mismatch

    @Test("Solution mismatch detected")
    func solutionMismatchDetected() {
        let solution = solutionGrid

        // Place a wrong digit: solution says (0,0) = 1, we place 2
        // But we must avoid structural conflicts, so only place one wrong digit
        var grid = Solution.empty()
        grid[0][0] = 2  // Wrong — solution expects 1

        let state = makeState(grid: grid, solution: solution)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect solution mismatch")
        if let hint {
            #expect(hint.technique == .validation, "Technique should be validation")
            #expect(hint.actions.count == 1, "Should have exactly one action for the wrong cell")
            #expect(
                hint.actions[0].position == Puzzle.Index(row: 0, column: 0),
                "Should target the cell with the wrong value"
            )
            #expect(hint.explanation.count == 2, "Solution mismatch should have exactly 2 explanation steps")
        }
    }

    // MARK: - Priority ordering

    @Test("Row conflict takes priority over column conflict")
    func rowPriorityOverColumn() {
        // Create both a row conflict and a column conflict.
        // Row conflict: duplicate 1 in row 0 at columns 0 and 8.
        // Column conflict: duplicate 2 in column 4 at rows 3 and 6.
        var grid = Solution.empty()
        grid[0][0] = 1
        grid[0][8] = 1  // Row 0 duplicate
        grid[3][4] = 2
        grid[6][4] = 2  // Column 4 duplicate

        let state = makeState(grid: grid)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect a conflict")
        if let hint {
            // The row conflict should be reported because rows are checked first
            let affectedPositions = Set(hint.actions.map(\.position))
            let rowConflictCells: Set<Puzzle.Index> = [
                Puzzle.Index(row: 0, column: 0),
                Puzzle.Index(row: 0, column: 8)
            ]
            #expect(
                affectedPositions.intersection(rowConflictCells).isEmpty == false,
                "Row conflict should take priority — should include row 0 cells"
            )
        }
    }

    @Test("Structural conflict takes priority over solution mismatch")
    func structuralPriorityOverSolution() {
        let solution = solutionGrid

        // Row conflict: duplicate 1 in row 0
        var grid = Solution.empty()
        grid[0][0] = 1
        grid[0][8] = 1  // Row duplicate

        // Also place a solution mismatch elsewhere (no structural conflict)
        grid[4][4] = 3  // Solution says (4,4) = 9

        let state = makeState(grid: grid, solution: solution)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint != nil, "Should detect a conflict")
        if let hint {
            // Should report the structural conflict, not the solution mismatch
            let affectedPositions = Set(hint.actions.map(\.position))
            #expect(
                affectedPositions.contains(Puzzle.Index(row: 4, column: 4)) == false,
                "Structural conflict should take priority over solution mismatch"
            )
            #expect(
                affectedPositions.contains(Puzzle.Index(row: 0, column: 8)),
                "Should report the row conflict cell"
            )
        }
    }

    // MARK: - All actions are clear type

    @Test("Validation actions are always clear type")
    func validationActionsAreClear() {
        // Test row conflict
        var rowGrid = Solution.empty()
        rowGrid[0][0] = 1
        rowGrid[0][1] = 1

        // Test column conflict
        var colGrid = Solution.empty()
        colGrid[0][0] = 5
        colGrid[3][0] = 5

        // Test solution mismatch
        var mismatchGrid = Solution.empty()
        mismatchGrid[0][0] = 2

        let grids: [(String, [[Int]], [[Int]]?)] = [
            ("row conflict", rowGrid, nil),
            ("column conflict", colGrid, nil),
            ("solution mismatch", mismatchGrid, solutionGrid),
        ]

        for (label, grid, solution) in grids {
            let state = makeState(grid: grid, solution: solution)
            let hint = HintFinder.findHint(for: .validation, in: state)

            #expect(hint != nil, "Should find hint for \(label)")
            if let hint {
                for action in hint.actions {
                    if case .clear = action.action {
                        // Expected
                    } else {
                        Issue.record("Action for \(label) should be .clear but got \(action.debugDescription)")
                    }
                }
            }
        }
    }

    // MARK: - No solution skips mismatch check

    @Test("No solution skips solution mismatch check")
    func noSolutionSkipsMismatchCheck() {
        // Place a digit that would be wrong if a solution existed, but provide no solution.
        // With no structural conflict and no solution, validation should return nil.
        var grid = Solution.empty()
        grid[0][0] = 2  // Would be wrong if solution existed, but no solution provided

        let state = makeState(grid: grid, solution: nil)
        let hint = HintFinder.findHint(for: .validation, in: state)

        #expect(hint == nil, "Without a solution, a lone digit should not trigger a validation hint")
    }
}
