//
//  PersonalizedCalibrator.swift
//  SudokuCore
//
//  Efficient per-user residual calibrator on top of a fixed baseline f0(rating).
//  Learns a multiplicative factor k(r) from recent samples and predicts
//  time = f0(r) * k_pred with simple, robust interpolation.
//

import Foundation

public struct PersonalizedCalibrator: Sendable, Equatable {
    public struct Anchor: Sendable, Equatable {
        public let rating: Int
        public let minutes: Double
        public init(rating: Int, minutes: Double) {
            self.rating = rating
            self.minutes = minutes
        }
    }
    public struct Sample: Sendable, Equatable { public let rating: Int; public let factor: Double; public let timestamp: Date }
    public struct Estimate: Sendable, Equatable {
        public let seconds: Int
        public let rangeLower: Int
        public let rangeUpper: Int
        public let factor: Double
    }

    private var anchors: [Anchor]
    private var samples: [Sample] = []
    private let maxSamples: Int
    private let minFactor: Double
    private let maxFactor: Double

    public init(
        anchors: [Anchor] = [
            .init(rating: 100, minutes: 3),
            .init(rating: 300, minutes: 8),
            .init(rating: 600, minutes: 15),
            .init(rating: 1000, minutes: 25),
            .init(rating: 1600, minutes: 50),
            .init(rating: 2000, minutes: 80)
        ],
        maxSamples: Int = 100,
        minFactor: Double = 0.2,
        maxFactor: Double = 4.0
    ) {
        self.anchors = anchors.sorted { $0.rating < $1.rating }
        self.maxSamples = maxSamples
        self.minFactor = minFactor
        self.maxFactor = maxFactor
    }

    /// Baseline seconds from anchor curve (linear interpolation; linear extrapolation at ends)
    public func baselineSeconds(for rating: Int) -> Int {
        guard let first = anchors.first, let last = anchors.last else { return 60 * 3 }
        if rating <= first.rating {
            // Extrapolate below first
            if anchors.count >= 2 {
                let a = anchors[0], b = anchors[1]
                let slope = (b.minutes - a.minutes) / Double(b.rating - a.rating)
                let minutes = a.minutes + slope * Double(rating - a.rating)
                return max(60, Int((minutes * 60).rounded()))
            } else {
                return max(60, Int((first.minutes * 60).rounded()))
            }
        }
        if rating >= last.rating {
            if anchors.count >= 2 {
                let a = anchors[anchors.count - 2], b = anchors[anchors.count - 1]
                let slope = (b.minutes - a.minutes) / Double(b.rating - a.rating)
                let minutes = b.minutes + slope * Double(rating - b.rating)
                return max(60, Int((minutes * 60).rounded()))
            } else {
                return max(60, Int((last.minutes * 60).rounded()))
            }
        }
        for i in 0..<(anchors.count - 1) {
            let a = anchors[i], b = anchors[i + 1]
            if rating >= a.rating && rating <= b.rating {
                let alpha = Double(rating - a.rating) / Double(b.rating - a.rating)
                let minutes = (1 - alpha) * a.minutes + alpha * b.minutes
                return max(60, Int((minutes * 60).rounded()))
            }
        }
        return max(60, Int((last.minutes * 60).rounded()))
    }

    /// Update calibrator with an observed completion time for a given rating.
    public mutating func update(rating: Int, timeSeconds: Int, at timestamp: Date = Date()) {
        let base = max(1, baselineSeconds(for: rating))
        let raw = Double(timeSeconds) / Double(base)
        let k = min(max(raw, minFactor), maxFactor)
        samples.append(Sample(rating: rating, factor: k, timestamp: timestamp))
        if samples.count > maxSamples {
            // Drop oldest by timestamp
            if let idx = samples.enumerated().min(by: { $0.element.timestamp < $1.element.timestamp })?.offset {
                samples.remove(at: idx)
            }
        }
    }

    /// Predict personalized time for a target rating, returning seconds and a range. O(n log n)
    public func predict(for rating: Int) -> Estimate {
        let base = baselineSeconds(for: rating)
        if samples.isEmpty {
            return Estimate(seconds: base, rangeLower: max(30, Int(Double(base) * 0.875)), rangeUpper: Int(Double(base) * 1.125), factor: 1.0)
        }

        if samples.count == 1 {
            let f = samples[0].factor
            let seconds = Int((Double(base) * f).rounded())
            let spread = max(15.0, Double(seconds) * 0.125)
            return Estimate(seconds: seconds, rangeLower: max(30, Int(Double(seconds) - spread)), rangeUpper: Int(Double(seconds) + spread), factor: f)
        }

        // Interpolate factor across nearest neighbors in rating space
        let sorted = samples.sorted { $0.rating < $1.rating }
        var lowerSample = sorted.first!
        var upperSample = sorted.last!
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i]; let b = sorted[i + 1]
            if rating >= a.rating && rating <= b.rating {
                lowerSample = a; upperSample = b; break
            }
        }

        let kPred: Double
        if rating <= sorted.first!.rating {
            let edge = sorted.first!.factor
            kPred = 0.7 * edge + 0.3 * 1.0
        } else if rating >= sorted.last!.rating {
            let edge = sorted.last!.factor
            kPred = 0.7 * edge + 0.3 * 1.0
        } else {
            let denom = max(1, upperSample.rating - lowerSample.rating)
            let alpha = Double(rating - lowerSample.rating) / Double(denom)
            kPred = (1 - alpha) * lowerSample.factor + alpha * upperSample.factor
        }

        let seconds = max(30, Int((Double(base) * kPred).rounded()))

        // Range from local MAD of factors (window size up to 5 around the bracket), fallback ±12.5%
        let window = localWindow(around: rating, in: sorted, count: 5)
        let factors = window.map { $0.factor }
        let spreadFactor = max(0.125, mad(values: factors))
        let lowSec = max(30, Int((Double(seconds) * (1 - spreadFactor)).rounded()))
        let highSec = Int((Double(seconds) * (1 + spreadFactor)).rounded())
        return Estimate(seconds: seconds, rangeLower: lowSec, rangeUpper: highSec, factor: kPred)
    }

    public var sampleCount: Int { samples.count }

    // MARK: - Helpers

    private func localWindow(around rating: Int, in sorted: [Sample], count: Int) -> [Sample] {
        if sorted.isEmpty { return [] }
        // Find closest index by rating
        var idx = 0
        var best = Int.max
        for (i, s) in sorted.enumerated() {
            let d = abs(s.rating - rating)
            if d < best { best = d; idx = i }
        }
        let half = count / 2
        let start = max(0, idx - half)
        let end = min(sorted.count, start + count)
        return Array(sorted[start..<end])
    }

    private func mad(values: [Double]) -> Double {
        guard values.count >= 3 else { return 0.0 }
        let median = values.sorted()[values.count / 2]
        let deviations = values.map { abs($0 - median) }.sorted()
        let mad = deviations[deviations.count / 2]
        // Scale to approximate std dev for normal dist
        return 1.4826 * mad
    }
}
