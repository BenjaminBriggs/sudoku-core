//
//  TimeEstimator.swift
//  SudokuCore
//
//  Estimates solve time from HoDoKu rating, with optional personalization.
//

import Foundation

public enum TimeEstimator {
    public struct Estimate: Sendable, Equatable {
        public let baselineSeconds: Int
        public let personalizedSeconds: Int?
        public let rangeLower: Int
        public let rangeUpper: Int
    }

    /// Convert a HoDoKu rating into a baseline time estimate (seconds).
    /// Placeholder: log-linear model; consider a table-driven mapping later.
    public static func baselineSeconds(fromHoDoKu rating: Int) -> Int {
        let r = max(1, rating)
        let (a, b) = RatingTables.TimeMapping.logModel
        let minutes = a + b * log(Double(r))
        return max(60, Int((minutes * 60).rounded()))
    }

    /// Apply a user speed factor (e.g., median of actual/baseline ratios) and return a range.
    public static func estimate(fromHoDoKu rating: Int, userSpeedFactor: Double? = nil) -> Estimate {
        let base = baselineSeconds(fromHoDoKu: rating)
        let personalized: Int? = {
            guard let f = userSpeedFactor else { return nil }
            let clamped = max(0.4, min(2.5, f))
            return Int((Double(base) * clamped).rounded())
        }()

        let center = Double(personalized ?? base)
        let spread = max(15.0, center * 0.125) // ±12.5% or ±15s minimum
        let lower = max(30, Int((center - spread).rounded()))
        let upper = Int((center + spread).rounded())
        return Estimate(baselineSeconds: base, personalizedSeconds: personalized, rangeLower: lower, rangeUpper: upper)
    }
}
