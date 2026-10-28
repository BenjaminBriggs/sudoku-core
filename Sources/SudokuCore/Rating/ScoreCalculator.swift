//
//  ScoreCalculator.swift
//  SudokuCore
//
//  Computes SudokuCore's score from a solve path: the level, and the effort split into
//  difficulty and tedium.
//

import Foundation

/// SudokuCore's own rating: each step of the solve adds its technique's
/// ``TechniqueInfo/scorePoints`` (HoDoKu 2.6's step scores), regardless of how many
/// eliminations the step makes, and the sum splits in two:
/// - **difficulty**: the steps beyond singles, the skill the puzzle asks for
/// - **tedium**: the singles, 4 a naked and 14 a hidden one, the slog
///
/// The level is the hardest step's ``TechniqueInfo/level``, nothing else. Unlike HoDoKu, a
/// long path never promotes a puzzle: fifty singles are a tedious Beginner puzzle, and one
/// W-Wing after twenty singles is an Advanced one. Guessing is Master.
///
/// ``HoDoKuCalculator`` estimates HoDoKu's own rating, with its score bands, for comparison.
public enum ScoreCalculator {
    public struct Score: Sendable, Equatable {
        /// Points over every step: `difficulty + tedium`.
        public let score: Int
        /// Points over the steps beyond singles. Orders puzzles within a level: one W-Wing is
        /// 150, a W-Wing and three pointings 300.
        public let difficulty: Int
        /// Points over the singles: the number of blanks, weighted by how much scanning they take.
        public let tedium: Int
        /// The hardest step's level; `.easy` for a path with no steps.
        public let level: PuzzleDifficulty.Level
        /// The points each technique adds.
        public let breakdown: [TechniqueID: Int]
    }

    /// The score of `grid`, solved in the hint finder's order.
    public static func compute(for grid: [[Int]]) -> Score {
        compute(from: SolvePathEmitter.emit(from: grid))
    }

    /// The score of a precomputed solve path.
    public static func compute(from path: SolvePathEmitter.SolvePath) -> Score {
        compute(from: path.steps.map(\.technique))
    }

    /// The score of a sequence of steps, each its technique.
    static func compute(from techniques: [TechniqueInfo]) -> Score {
        var difficulty = 0
        var tedium = 0
        var level = PuzzleDifficulty.Level.easy
        var breakdown: [TechniqueID: Int] = [:]
        for technique in techniques {
            let points = Int((technique.scorePoints ?? 0).rounded())
            breakdown[technique.id, default: 0] += points
            if technique.isSingle { tedium += points } else { difficulty += points }
            level = max(level, technique.level)
        }
        return Score(
            score: difficulty + tedium, difficulty: difficulty, tedium: tedium,
            level: level, breakdown: breakdown)
    }
}
