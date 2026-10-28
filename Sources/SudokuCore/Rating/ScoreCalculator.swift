//
//  ScoreCalculator.swift
//  SudokuCore
//
//  Computes SudokuCore's cumulative effort score from a solve path.
//

import Foundation

/// SudokuCore's own difficulty score: each step of the solve adds its technique's
/// ``TechniqueInfo/scorePoints``, regardless of how many eliminations the step makes.
/// ``PuzzleDifficulty/Level/scoreRange`` turns the score into a level.
///
/// The method is HoDoKu's, but the points and levels are SudokuCore's. ``HoDoKuCalculator``
/// estimates HoDoKu's own rating.
public enum ScoreCalculator {
    public struct Score: Sendable, Equatable {
        public let score: Int
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
        var total = 0
        var breakdown: [TechniqueID: Int] = [:]
        for step in path.steps {
            let points = Int((step.technique.scorePoints ?? 0).rounded())
            breakdown[step.technique.id, default: 0] += points
            total += points
        }
        let level = PuzzleDifficulty.Level.allCases.first { $0.scoreRange.contains(total) }!
        return Score(score: total, level: level, breakdown: breakdown)
    }
}
