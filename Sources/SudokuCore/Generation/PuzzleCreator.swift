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
        let difficultyResult = try await SudokuDifficultyCalculator.calculateDifficulty(
            for: startingState
        )

        return Puzzle(
            solution: solution,
            startingState: startingState,
            difficulty: difficultyResult.puzzleDifficulty
        )
    }

    /// Create a puzzle with a specific difficulty goal
    /// - Parameters:
    ///   - targetDifficulty: The desired difficulty level
    ///   - maxAttempts: Maximum number of attempts to generate a matching puzzle
    /// - Returns: A Puzzle with the requested difficulty, or the closest match
    public static func createPuzzleWithDifficulty(
        _ targetDifficulty: PuzzleDifficulty.Level,
        maxAttempts: Int = 20
    ) async throws -> Puzzle {
        var bestMatch:
            (
                puzzle: [[Int]], solution: [[Int]],
                difficultyResult: SudokuDifficultyCalculator.DifficultyResult
            )? = nil
        var bestDifficultyDistance = Int.max

        // Target technique difficulty ranges for different puzzle difficulty levels
        let difficultyTargets: [PuzzleDifficulty.Level: ClosedRange<Int>] = [
            .easy: 0...40,  // Up to locked candidates
            .medium: 41...70,  // Naked/hidden pair, triple techniques
            .hard: 71...100,  // X-Wing, swordfish, Y-Wing, etc.
            .expert: 101...115,  // Advanced wings and fish
            .professional: 116...120,  // Most advanced techniques
            .custom: 100...120,  // Most advanced techniques
        ]

        // Get target range for requested difficulty
        let targetRange = difficultyTargets[targetDifficulty] ?? (0...50)

        for attempt in 1...maxAttempts {
            // Choose generation strategy based on target difficulty
            var targetsEmptyCells: ClosedRange<Int>
            switch targetDifficulty {
            case .easy:
                targetsEmptyCells = 35...45
            case .medium:
                targetsEmptyCells = 46...55
            case .hard:
                targetsEmptyCells = 56...60
            case .expert:
                targetsEmptyCells = 58...62
            case .professional:
                targetsEmptyCells = 60...64
            case .custom:
                targetsEmptyCells = 56...64
            }

            // Generate a puzzle
            let solution = SolutionGenerator.generateRandomSolution()
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: Int.random(in: targetsEmptyCells)
            )

            // Skip if not uniquely solvable
            guard Validator.hasUniqueSolution(puzzle) else { continue }

            // Calculate difficulty - skip if calculation fails
            let difficultyResult: SudokuDifficultyCalculator.DifficultyResult
            do {
                difficultyResult = try await SudokuDifficultyCalculator.calculateDifficulty(
                    for: puzzle
                )
            } catch {
                // Skip puzzles that fail difficulty calculation
                continue
            }

            // Skip if the puzzle couldn't be solved using our techniques
            guard difficultyResult.wasSolved else { continue }

            // Check if difficulty matches our target
            let highestDifficulty = difficultyResult.hardestTechnique?.difficulty ?? 0
            let difficultyDistance = distanceToTargetRange(
                highestDifficulty, targetRange: targetRange)

            // If we have a perfect match, use it immediately
            if difficultyDistance == 0 {
                bestMatch = (puzzle, solution, difficultyResult)
                break
            }

            // Update best match if this is closer to our target
            if difficultyDistance < bestDifficultyDistance {
                bestMatch = (puzzle, solution, difficultyResult)
                bestDifficultyDistance = difficultyDistance
            }

            // If we're close enough, stop early
            if bestDifficultyDistance < 10 && attempt > 5 {
                break
            }
        }

        // Create the puzzle using the best match
        if let (puzzle, solution, difficultyResult) = bestMatch {
            return Puzzle(
                solution: solution,
                startingState: puzzle,
                difficulty: difficultyResult.puzzleDifficulty
            )
        }

        // If we couldn't find a suitable puzzle, generate a basic one
        let (solution, startingState) = await SudokuGenerator.generatePuzzle()
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
