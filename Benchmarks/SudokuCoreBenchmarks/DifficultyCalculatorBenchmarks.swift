//
//  DifficultyCalculatorBenchmarks.swift
//  SudokuCore
//
//  Benchmarks for difficulty calculation - the main bottleneck in puzzle generation
//

import Benchmark
import SudokuCore

// MARK: - Difficulty Calculator Benchmarks

let difficultyCalculatorBenchmarks: @Sendable () -> Void = {
    // Easy puzzle - should be fastest (fewer iterations)
    Benchmark("DifficultyCalculator.Easy", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one
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
            do {
                let result = try SudokuDifficultyCalculator.calculateDifficulty(for: easyPuzzle)
                blackHole(result)
            } catch {
                blackHole(error)
            }
        }
    }

    // Medium puzzle - moderate complexity
    Benchmark("DifficultyCalculator.Medium", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one
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
            do {
                let result = try SudokuDifficultyCalculator.calculateDifficulty(for: mediumPuzzle)
                blackHole(result)
            } catch {
                blackHole(error)
            }
        }
    }

    // Hard puzzle - most complex (many iterations, advanced techniques)
    Benchmark("DifficultyCalculator.Hard", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one
    )) { benchmark in
        let hardPuzzle: [[Int]] = [
            [0, 0, 0, 2, 0, 0, 0, 6, 3],
            [3, 0, 0, 0, 0, 5, 4, 0, 1],
            [0, 0, 1, 0, 0, 3, 9, 8, 0],
            [0, 0, 0, 0, 0, 0, 0, 9, 0],
            [0, 0, 0, 5, 3, 8, 0, 0, 0],
            [0, 3, 0, 0, 0, 0, 0, 0, 0],
            [0, 2, 6, 3, 0, 0, 5, 0, 0],
            [5, 0, 3, 7, 0, 0, 0, 0, 8],
            [4, 7, 0, 0, 0, 1, 0, 0, 0]
        ]

        for _ in benchmark.scaledIterations {
            do {
                let result = try SudokuDifficultyCalculator.calculateDifficulty(for: hardPuzzle)
                blackHole(result)
            } catch {
                blackHole(error)
            }
        }
    }

    // Real-world scenario: Generate and rate multiple puzzles
    // This simulates the puzzle generation loop
    Benchmark("DifficultyCalculator.GenerationLoop", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 10
    )) { benchmark in
        // Mix of different difficulty puzzles
        let puzzles: [[[Int]]] = [
            // Easy
            [
                [0, 3, 4, 6, 7, 8, 9, 1, 2],
                [6, 0, 2, 1, 9, 5, 3, 4, 8],
                [1, 9, 0, 3, 4, 2, 5, 6, 7],
                [8, 5, 9, 0, 6, 1, 4, 2, 3],
                [4, 2, 6, 8, 0, 3, 7, 9, 1],
                [7, 1, 3, 9, 2, 0, 8, 5, 6],
                [9, 6, 1, 5, 3, 7, 0, 8, 4],
                [2, 8, 7, 4, 1, 9, 6, 0, 5],
                [3, 4, 5, 2, 8, 6, 1, 7, 0]
            ],
            // Medium
            [
                [5, 3, 0, 0, 7, 0, 0, 0, 0],
                [6, 0, 0, 1, 9, 5, 0, 0, 0],
                [0, 9, 8, 0, 0, 0, 0, 6, 0],
                [8, 0, 0, 0, 6, 0, 0, 0, 3],
                [4, 0, 0, 8, 0, 3, 0, 0, 1],
                [7, 0, 0, 0, 2, 0, 0, 0, 6],
                [0, 6, 0, 0, 0, 0, 2, 8, 0],
                [0, 0, 0, 4, 1, 9, 0, 0, 5],
                [0, 0, 0, 0, 8, 0, 0, 7, 9]
            ],
            // Hard
            [
                [0, 0, 0, 2, 0, 0, 0, 6, 3],
                [3, 0, 0, 0, 0, 5, 4, 0, 1],
                [0, 0, 1, 0, 0, 3, 9, 8, 0],
                [0, 0, 0, 0, 0, 0, 0, 9, 0],
                [0, 0, 0, 5, 3, 8, 0, 0, 0],
                [0, 3, 0, 0, 0, 0, 0, 0, 0],
                [0, 2, 6, 3, 0, 0, 5, 0, 0],
                [5, 0, 3, 7, 0, 0, 0, 0, 8],
                [4, 7, 0, 0, 0, 1, 0, 0, 0]
            ]
        ]

        for _ in benchmark.scaledIterations {
            for puzzle in puzzles {
                do {
                    let result = try SudokuDifficultyCalculator.calculateDifficulty(for: puzzle)
                    blackHole(result)
                } catch {
                    blackHole(error)
                }
            }
        }
    }
}
