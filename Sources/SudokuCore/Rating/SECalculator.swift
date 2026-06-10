//
//  SECalculator.swift
//  SudokuCore
//
//  Computes a Sudoku Explainer-style rating from a solve path.
//

import Foundation

public enum SECalculator {
    public struct SEResult: Sendable, Equatable {
        public let rating: Double
        public let hardestTechniqueName: String
        public let maxStepIndex: Int
        public let usedTechniques: [String]
        public let pathSummary: [String: Int]
    }

    /// Compute SE rating for a puzzle using on-enum step values.
    public static func compute(for grid: [[Int]]) -> SEResult {
        let path = SolvePathEmitter.emit(from: grid)
        return compute(from: path)
    }

    /// Compute SE rating from a precomputed solve path.
    public static func compute(from path: SolvePathEmitter.SolvePath) -> SEResult {
        var maxValue: Double = 0
        var maxIndex: Int = -1
        var summary: [String: Int] = [:]

        for (idx, step) in path.steps.enumerated() {
            let key = TechniqueMapping.seId(for: step.technique)
            summary[key, default: 0] += 1
            let value: Double = step.technique.seStepValue ?? 0
            if value > maxValue {
                maxValue = value
                maxIndex = idx
            }
        }

        let hardestName = path.steps.indices.contains(maxIndex)
            ? TechniqueMapping.seId(for: path.steps[maxIndex].technique)
            : "None"

        return SEResult(
            rating: (maxValue * 10).rounded() / 10.0, // one decimal place
            hardestTechniqueName: hardestName,
            maxStepIndex: maxIndex,
            usedTechniques: Array(summary.keys).sorted(),
            pathSummary: summary
        )
    }
}
