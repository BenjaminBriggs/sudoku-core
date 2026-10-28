//
//  PuzzleCreator.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//

import Foundation

/// Creates puzzle objects with calculated difficulty based on hint techniques
public struct PuzzleCreator {
    /// Create a puzzle from a solution and starting state
    /// - Parameters:
    ///   - solution: The complete Sudoku solution
    ///   - startingState: The initial state with some empty cells
    /// - Returns: A Puzzle object with calculated difficulty
    public static func createPuzzle(
        solution: [[Int]],
        startingState: [[Int]]
    ) async throws -> Puzzle {
        // Calculate difficulty
        let difficultyResult = try SudokuDifficultyCalculator.calculateDifficulty(
            for: startingState
        )

        return Puzzle(
            solution: solution,
            startingState: startingState,
            difficulty: difficultyResult.puzzleDifficulty
        )
    }

    /// Create a puzzle with a specific difficulty goal
    ///
    /// Built on ``SudokuGenerator/createPuzzle(level:symmetry:givens:from:maxRatings:bestEffort:)``,
    /// so the level is the calculator's own and the puzzle never needs guessing.
    /// - Parameters:
    ///   - targetDifficulty: The desired difficulty level
    ///   - maxAttempts: Maximum number of solutions to try
    ///   - symmetry: The symmetry the clue layout keeps (defaults to `.none`)
    /// - Returns: A Puzzle with the requested difficulty, or the closest match
    public static func createPuzzleWithDifficulty(
        _ targetDifficulty: PuzzleDifficulty.Level,
        maxAttempts: Int = 20,
        symmetry: Symmetry = .none
    ) async throws -> Puzzle {
        let targetRange = targetDifficulty.scoreRange
        var closest: SteeredPuzzle?

        for _ in 1...max(1, maxAttempts) {
            // Each attempt is a full generate + search; a caller that has moved on
            // (a new difficulty, a dismissed screen) should not pay for the rest.
            try Task.checkCancellation()

            guard
                let steered = SudokuGenerator.createPuzzle(
                    level: targetDifficulty,
                    symmetry: symmetry,
                    bestEffort: true
                )
            else { continue }
            if steered.matchesLevel {
                return steered.puzzle
            }
            let distance = distanceToTargetRange(Int(steered.result.score), targetRange: targetRange)
            let closestDistance = closest.map {
                distanceToTargetRange(Int($0.result.score), targetRange: targetRange)
            }
            if distance < closestDistance ?? .max {
                closest = steered
            }
        }
        try Task.checkCancellation()

        if let closest {
            return closest.puzzle
        }

        // If we couldn't find a suitable puzzle, generate a basic one
        let (solution, startingState) = await SudokuGenerator.generatePuzzle(symmetry: symmetry)
        return try await createPuzzle(solution: solution, startingState: startingState)
    }

    /// Calculate distance to the target range
    /// - Parameters:
    ///   - value: The value to check
    ///   - targetRange: The target range
    /// - Returns: How far outside the range the value is (0 if inside)
    private static func distanceToTargetRange(_ value: Int, targetRange: ClosedRange<Int>) -> Int {
        if targetRange.contains(value) {
            return 0
        } else if value < targetRange.lowerBound {
            return targetRange.lowerBound - value
        } else {
            return value - targetRange.upperBound
        }
    }
}
