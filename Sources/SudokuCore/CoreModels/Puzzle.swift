//
//  Puzzle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//
import Foundation

public struct Puzzle: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let solution: [[Int]]
    public let startingState: [[Int]]
    public let difficulty: PuzzleDifficulty
    public init(
        solution: [[Int]],
        startingState: [[Int]],
        difficulty: PuzzleDifficulty
    ) {
        self.id = startingState.flatString(empty: "0")
        self.solution = solution
        self.startingState = startingState
        self.difficulty = difficulty
    }
}

/// Represents the intrinsic difficulty of a Sudoku puzzle
///
/// # HoDoKu Rating System
/// The `score` field represents the puzzle's HoDoKu cumulative effort rating,
/// calculated by summing points for each solving technique used. This is a well-established
/// standard used by the Sudoku community.
///
/// ## Difficulty Levels (HoDoKu Points)
/// - **Beginner (1-300)**: Primarily basic techniques (naked/hidden singles)
/// - **Intermediate (301-600)**: Intermediate techniques (pairs, triples, locked candidates)
/// - **Advanced (601-1000)**: Advanced techniques (X-Wing, Swordfish, Wings)
/// - **Expert (1001-1600)**: Complex chains and advanced patterns
/// - **Master (1601-2000+)**: Extreme techniques and complex solving paths
/// - **Custom (>2000)**: Special or modified puzzles
///
/// ## Additional Ratings
/// - **seRating**: Sudoku Explainer rating (difficulty of hardest technique)
/// - **hodokuRating**: Same as score, stored separately for clarity
/// - **estimatedTimeSeconds**: Predicted completion time
///
/// This base rating is separate from performance scoring, which evaluates how well
/// a player completed the puzzle (time, hints used, errors made).
public struct PuzzleDifficulty: Sendable, Codable, Hashable {
    /// Difficulty category (easy, medium, hard, expert, professional, custom)
    public let level: Level

    /// Most advanced technique required to solve the puzzle
    public let hardestTechnique: HintTechnique

    /// HoDoKu cumulative effort rating
    /// Represents intrinsic puzzle difficulty independent of player performance
    public let score: Int

    /// Optional standard ratings and time estimate
    public let seRating: Double?
    public let hodokuRating: Int?
    public let estimatedTimeSeconds: Int?

    public init(
        level: Level,
        hardestTechnique: HintTechnique,
        score: Int,
        seRating: Double? = nil,
        hodokuRating: Int? = nil,
        estimatedTimeSeconds: Int? = nil
    ) {
        self.level = level
        self.hardestTechnique = hardestTechnique
        self.score = score
        self.seRating = seRating
        self.hodokuRating = hodokuRating
        self.estimatedTimeSeconds = estimatedTimeSeconds
    }

    public enum Level: String, Codable, Hashable, CaseIterable, Sendable {
        case easy
        case medium
        case hard
        case expert
        case professional
        case custom
    }
}

extension Puzzle {
    public static func example() -> Puzzle {
        .init(
            solution: [
                [8, 2, 9, 1, 3, 5, 7, 4, 6],
                [1, 3, 4, 8, 6, 7, 2, 5, 9],
                [6, 7, 5, 4, 2, 9, 1, 3, 8],

                [3, 8, 1, 2, 7, 4, 9, 6, 5],
                [7, 5, 6, 3, 9, 8, 4, 2, 1],
                [9, 4, 2, 6, 5, 1, 3, 8, 7],

                [5, 9, 8, 7, 4, 3, 6, 1, 2],
                [4, 6, 7, 5, 1, 2, 8, 9, 3],
                [2, 1, 3, 9, 8, 6, 5, 7, 4],
            ],
            startingState: [
                [8, 0, 0, 0, 0, 5, 0, 4, 0],
                [1, 0, 0, 0, 0, 7, 2, 0, 9],
                [6, 0, 0, 0, 2, 0, 0, 3, 0],

                [0, 0, 0, 0, 0, 4, 9, 6, 5],
                [7, 5, 0, 3, 9, 0, 0, 2, 1],
                [9, 0, 0, 6, 5, 0, 0, 0, 7],

                [5, 9, 0, 7, 0, 3, 6, 1, 0],
                [4, 0, 0, 0, 0, 0, 8, 0, 0],
                [2, 0, 3, 9, 8, 0, 0, 0, 0],
            ],
            difficulty: PuzzleDifficulty(
                level: .easy,
                hardestTechnique: .hiddenSingle,
                score: 0
            )
        )
    }
}
