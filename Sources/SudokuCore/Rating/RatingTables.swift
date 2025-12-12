//
//  RatingTables.swift
//  SudokuCore
//
//  Swift-native default tables for SE, HoDoKu and time mapping.
//  Replace values during calibration as needed; calculators can also accept
//  injected tables for tests or alternative configurations.
//

import Foundation

public enum RatingTables {
    public enum HoDoKu {
        /// Map HoDoKu cumulative points to our PuzzleDifficulty.Level.
        /// We currently expose only .easy/.medium/.hard; we collapse multiple
        /// HoDoKu classes into these until we add finer-grained levels.
        public static let classThresholds: [(level: PuzzleDifficulty.Level, maxPoints: Int)] = [
            (.easy, 300),  // Basic + Easy
            (.medium, 600),  // Moderate
            (.hard, 1000),  // Hard
            (.expert, 1600),  // Very Hard
            (.professional, Int.max),  // Extreme
        ]
    }

    public enum TimeMapping {
        /// Log-linear model parameters for baseline minutes.
        public static let logModel: (a: Double, b: Double) = (2.0, 2.2)

        /// Optional class-based ranges (minutes); can be used for UI hints.
        public static let classRangesMinutes: [String: (min: Int, max: Int)] = [
            "Basic": (2, 4),
            "Easy": (4, 8),
            "Moderate": (8, 15),
            "Hard": (15, 25),
            "Very Hard": (25, 40),
            "Extreme": (40, 90),
        ]
    }
}
