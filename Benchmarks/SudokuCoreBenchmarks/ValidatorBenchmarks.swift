//
//  ValidatorBenchmarks.swift
//  SudokuCore
//
//  Benchmarks for Validator functions - hot path operations
//

import Benchmark
import SudokuCore

// MARK: - Validator Benchmarks

let validatorBenchmarks: @Sendable () -> Void = {
    // validOptions is called after every hint application
    // This is a critical hot path in difficulty calculation
    Benchmark("Validator.validOptions-Empty", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .kilo
    )) { benchmark in
        let emptyGrid = Array(repeating: Array(repeating: 0, count: 9), count: 9)

        for _ in benchmark.scaledIterations {
            let result = Validator.validOptions(for: emptyGrid)
            blackHole(result)
        }
    }

    // Partially filled grid - more realistic scenario
    Benchmark("Validator.validOptions-Partial", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .kilo
    )) { benchmark in
        let partialGrid: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9]
        ]

        for _ in benchmark.scaledIterations {
            let result = Validator.validOptions(for: partialGrid)
            blackHole(result)
        }
    }

    // Nearly complete grid - less work to do
    Benchmark("Validator.validOptions-NearlyComplete", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .kilo
    )) { benchmark in
        let nearlyCompleteGrid: [[Int]] = [
            [0, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 0, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 0, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 0, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 0, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 0, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 0, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 0, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 0]
        ]

        for _ in benchmark.scaledIterations {
            let result = Validator.validOptions(for: nearlyCompleteGrid)
            blackHole(result)
        }
    }

    // hasNoConflicts - used in validation
    Benchmark("Validator.hasNoConflicts", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .kilo
    )) { benchmark in
        let validGrid: [[Int]] = [
            [5, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 7, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 8, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 7, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 5, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 4, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 2, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 3, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 9]
        ]

        for _ in benchmark.scaledIterations {
            let result = Validator.hasNoConflicts(in: validGrid)
            blackHole(result)
        }
    }

    // hasUniqueSolution - expensive but critical for puzzle generation
    Benchmark("Validator.hasUniqueSolution-Easy", configuration: .init(
        metrics: [.wallClock, .cpuUser],
        scalingFactor: .one,
        maxIterations: 100
    )) { benchmark in
        let easyPuzzle: [[Int]] = [
            [0, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 0, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 0, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 0, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 0, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 0, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 0, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 0, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 0]
        ]

        for _ in benchmark.scaledIterations {
            let result = Validator.hasUniqueSolution(easyPuzzle)
            blackHole(result)
        }
    }

    // hasUniqueSolution on harder puzzle (more backtracking)
    Benchmark("Validator.hasUniqueSolution-Medium", configuration: .init(
        metrics: [.wallClock, .cpuUser],
        scalingFactor: .one,
        maxIterations: 50
    )) { benchmark in
        let mediumPuzzle: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9]
        ]

        for _ in benchmark.scaledIterations {
            let result = Validator.hasUniqueSolution(mediumPuzzle)
            blackHole(result)
        }
    }

    // isValid - called during solution generation
    Benchmark("Validator.isValid", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .mega
    )) { benchmark in
        let partialGrid: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9]
        ]

        for _ in benchmark.scaledIterations {
            // Test validity of placing a 4 at position (0, 2)
            let result = Validator.isValid(4, row: 0, column: 2, in: partialGrid)
            blackHole(result)
        }
    }
}