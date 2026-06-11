//
//  HoDoKuCalculator.swift
//  SudokuCore
//
//  Computes a HoDoKu-style cumulative effort rating from a solve path.
//

import Foundation

public enum HoDoKuCalculator {
    public struct HoDoKuResult: Sendable, Equatable {
        public let rating: Int
        public let classLabel: String
        public let breakdown: [String: Int] // techniqueId -> total points
    }

    /// Compute a HoDoKu-like rating using on-enum point values.
    public static func compute(for grid: [[Int]]) -> HoDoKuResult {
        let path = SolvePathEmitter.emit(from: grid)
        return compute(from: path)
    }

    /// Compute from a precomputed solve path.
    public static func compute(from path: SolvePathEmitter.SolvePath) -> HoDoKuResult {
        var total: Double = 0
        var breakdown: [String: Int] = [:]

        for step in path.steps {
            let key = TechniqueMapping.hodokuId(for: step.technique)
            // Standard HoDoKu scoring: fixed points per technique, regardless of
            // how many eliminations the step produces.
            let points = Int((step.technique.hodokuPoints ?? 0).rounded())
            breakdown[key, default: 0] += points
            total += Double(points)
        }

        let rating = Int(total.rounded())
        let label = classify(rating: rating)
        return HoDoKuResult(rating: rating, classLabel: label, breakdown: breakdown)
    }

    private static func classify(rating: Int) -> String {
        for (level, maxPoints) in RatingTables.HoDoKu.classThresholds {
            if rating <= maxPoints { return level.debugDescription }
        }
        return "Extreme"
    }
}
