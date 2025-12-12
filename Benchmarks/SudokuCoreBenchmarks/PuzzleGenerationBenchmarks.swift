//
//  PuzzleGenerationBenchmarks.swift
//  SudokuCore
//
//  Benchmarks for puzzle generation performance - the core bottleneck in puzzle creation
//

import Benchmark
import SudokuCore

// MARK: - Puzzle Generation Benchmarks

let puzzleGenerationBenchmarks: @Sendable () -> Void = {
    // Solution generation - baseline for how fast we can create valid Sudoku solutions
    Benchmark("PuzzleGeneration.SolutionOnly", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one
    )) { benchmark in
        for _ in benchmark.scaledIterations {
            let solution = SolutionGenerator.generateRandomSolution()
            blackHole(solution)
        }
    }

    // Creating puzzle from solution - easy difficulty (30-35 empty cells)
    Benchmark("PuzzleGeneration.CreatePuzzle-Easy", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 10
    )) { benchmark in
        // Generate solution once, reuse for all iterations
        let solution = SolutionGenerator.generateRandomSolution()
        for _ in benchmark.scaledIterations {
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: 32  // Easy difficulty target
            )
            blackHole(puzzle)
        }
    }

    // Creating puzzle from solution - medium difficulty (40-50 empty cells)
    Benchmark("PuzzleGeneration.CreatePuzzle-Medium", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 10
    )) { benchmark in
        let solution = SolutionGenerator.generateRandomSolution()
        for _ in benchmark.scaledIterations {
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: 45  // Medium difficulty target
            )
            blackHole(puzzle)
        }
    }

    // Creating puzzle from solution - hard difficulty (55-65 empty cells)
    Benchmark("PuzzleGeneration.CreatePuzzle-Hard", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 5
    )) { benchmark in
        let solution = SolutionGenerator.generateRandomSolution()
        for _ in benchmark.scaledIterations {
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: 60  // Hard difficulty target
            )
            blackHole(puzzle)
        }
    }

    // Full generation pipeline - solution + puzzle creation (easy)
    Benchmark("PuzzleGeneration.FullPipeline-Easy", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 10
    )) { benchmark in
        for _ in benchmark.scaledIterations {
            let result = await SudokuGenerator.generatePuzzle(
                targetsEmptyCells: 30...35
            )
            blackHole(result)
        }
    }

    // Full generation pipeline - solution + puzzle creation (medium)
    Benchmark("PuzzleGeneration.FullPipeline-Medium", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 10
    )) { benchmark in
        for _ in benchmark.scaledIterations {
            let result = await SudokuGenerator.generatePuzzle(
                targetsEmptyCells: 40...50
            )
            blackHole(result)
        }
    }

    // Full generation pipeline - solution + puzzle creation (hard)
    Benchmark("PuzzleGeneration.FullPipeline-Hard", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 5
    )) { benchmark in
        for _ in benchmark.scaledIterations {
            let result = await SudokuGenerator.generatePuzzle(
                targetsEmptyCells: 55...65
            )
            blackHole(result)
        }
    }

    // Complete generation loop - mimics real-world usage
    // Solution -> Puzzle -> Difficulty Calculation
    Benchmark("PuzzleGeneration.CompleteLoop", configuration: .init(
        metrics: [.wallClock, .cpuUser, .throughput],
        scalingFactor: .one,
        maxIterations: 5
    )) { benchmark in
        for _ in benchmark.scaledIterations {
            // Step 1: Generate solution
            let solution = SolutionGenerator.generateRandomSolution()

            // Step 2: Create puzzle
            let targetEmpty = Int.random(in: 35...55)
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: targetEmpty
            )

            // Step 3: Calculate difficulty
            do {
                let difficulty = try SudokuDifficultyCalculator.calculateDifficultySync(for: puzzle)
                blackHole(difficulty)
            } catch {
                blackHole(error)
            }
        }
    }
}
