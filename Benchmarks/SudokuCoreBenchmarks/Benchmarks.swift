//
//  Benchmarks.swift
//  SudokuCore
//
//  Performance benchmarks for hint finding and puzzle generation
//
//  The BenchmarkPlugin auto-generates the main entry point
//

import Benchmark

// Main benchmarks entry point - plugin calls this
let benchmarks: @Sendable () -> Void = {
    simpleTests()
    validatorBenchmarks()
    hintFinderBenchmarks()
    difficultyCalculatorBenchmarks()
    puzzleGenerationBenchmarks()
    calibratorBenchmarks()
}
