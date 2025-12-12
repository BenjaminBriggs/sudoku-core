//
//  SimpleTest.swift
//  Simple benchmark to test async functionality
//

import Benchmark
import SudokuCore

let simpleTests: @Sendable () -> Void = {
    // Super simple sync benchmark
    Benchmark("Simple.Sync") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(42)
        }
    }

    // Simple async function
    func simpleAsyncWork() async -> Int {
        return 42
    }

    // Simple async benchmark
    Benchmark("Simple.Async") { benchmark in
        for _ in benchmark.scaledIterations {
            let result = await simpleAsyncWork()
            blackHole(result)
        }
    }

    // Removed - HintFinder is now an enum with static methods
}
