//
//  PersonalizedCalibratorBenchmarks.swift
//  SudokuCore
//
//  Benchmarks for the residual calibrator.
//

import Foundation
import Benchmark
import SudokuCore

let calibratorBenchmarks: @Sendable () -> Void = {
    Benchmark("Calibrator.Update-100", configuration: .init(metrics: [.wallClock, .cpuUser, .throughput], scalingFactor: .one)) { benchmark in
        for _ in benchmark.scaledIterations {
            var cal = PersonalizedCalibrator()
            var ts = Date(timeIntervalSince1970: 0)
            for r in stride(from: 100, through: 2000, by: 20).prefix(100) {
                // synthetic factor around 0.9..1.1
                let base = cal.baselineSeconds(for: r)
                let seconds = Int(Double(base) * (0.9 + (Double((r % 11)) / 100.0)))
                cal.update(rating: r, timeSeconds: seconds, at: ts)
                ts = ts.addingTimeInterval(1)
            }
            blackHole(cal)
        }
    }

    Benchmark("Calibrator.Predict-1k", configuration: .init(metrics: [.wallClock, .cpuUser, .throughput], scalingFactor: .one)) { benchmark in
        var cal = PersonalizedCalibrator()
        var ts = Date(timeIntervalSince1970: 0)
        for r in stride(from: 150, through: 1900, by: 18).prefix(100) {
            let base = cal.baselineSeconds(for: r)
            let seconds = Int(Double(base) * (0.8 + (Double((r % 21)) / 100.0)))
            cal.update(rating: r, timeSeconds: seconds, at: ts)
            ts = ts.addingTimeInterval(1)
        }

        for _ in benchmark.scaledIterations {
            var acc = 0
            for r in stride(from: 100, through: 2000, by: 2).prefix(1000) {
                acc &+= cal.predict(for: r).seconds
            }
            blackHole(acc)
        }
    }
}
