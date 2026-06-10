//
//  HintFinderBenchmarks.swift
//  SudokuCore
//
//  Benchmarks for hint finding performance
//

import Benchmark
import SudokuCore

// Helper to parse grid strings into [[Int]]
private func parseGrid(_ gridString: String) -> [[Int]] {
    var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    for (index, char) in gridString.enumerated() {
        let row = index / 9
        let col = index % 9
        grid[row][col] = Int(String(char)) ?? 0
    }
    return grid
}

// Helper to create BoardState from grid
private func createBoardState(from grid: [[Int]]) -> BoardState {
    let pencilMarks = Validator.validOptions(for: grid)
    return BoardState(
        grid: grid,
        pencilMarks: pencilMarks,
        validOptions: pencilMarks
    )
}

// MARK: - Individual Technique Benchmarks

let hintFinderBenchmarks: @Sendable () -> Void = {
    // Naked Single - simplest technique
    Benchmark("HintFinder.NakedSingle") { benchmark in
        let grid = parseGrid("000000000000000000000000000000000000000000283000000154000000000000000070000000090")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.nakedSingle.id)?.findHint(in: state)  // 'await' makes closure async
            blackHole(hint)
        }
    }

    // Hidden Single
    Benchmark("HintFinder.HiddenSingle") { benchmark in
        let grid = parseGrid("000093000000005000000064000000000000000000000000000000000000000000700000000000000")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.hiddenSingle.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // Naked Pair
    Benchmark("HintFinder.NakedPair") { benchmark in
        let grid = parseGrid("658003421249185003713006598802030150037000286005800000586010042971000805324008017")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.nakedPair.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // Naked Triple
    Benchmark("HintFinder.NakedTriple") { benchmark in
        let grid = parseGrid("631480000000130806008960134006079000800256000570041600060518749985724361147693582")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.nakedTriple.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // X-Wing - expensive fish pattern
    Benchmark("HintFinder.XWing") { benchmark in
        let grid = parseGrid("040070180003100700170948035617890350009000071000701908791486523004017896068009417")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.xWing.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // Swordfish - more expensive fish pattern
    Benchmark("HintFinder.Swordfish") { benchmark in
        let grid = parseGrid("638005219149628000752193800820951030573860901000030508300509602265380190007216000")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.swordfish.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // Y-Wing
    Benchmark("HintFinder.YWing") { benchmark in
        let grid = parseGrid("387956412600024083420800096743519628162487935958002147200098354500240800804005200")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = ClassicTechniques.technique(for: TechniqueInfo.yWing.id)?.findHint(in: state)
            blackHole(hint)
        }
    }

    // Full hint search - tries all techniques in order
    Benchmark("HintFinder.FullSearch-Easy", configuration: .init(metrics: [.wallClock, .cpuUser, .throughput])) { benchmark in
        let grid = parseGrid("000000000000000000000000000000000000000000283000000154000000000000000070000000090")
        let state = createBoardState(from: grid)

        for _ in benchmark.scaledIterations {
            var foundHint: HintStep? = nil
            for technique in ClassicTechniques.all {
                if let hint = technique.findHint(in: state) {
                    foundHint = hint
                    break
                }
            }
            blackHole(foundHint)
        }
    }

    // Full hint search on harder puzzle
    Benchmark("HintFinder.FullSearch-Hard", configuration: .init(metrics: [.wallClock, .cpuUser, .throughput])) { benchmark in
        let grid = parseGrid("040070180003100700170948035617890350009000071000701908791486523004017896068009417")
        let state = createBoardState(from: grid)

        for _ in benchmark.scaledIterations {
            var foundHint: HintStep? = nil
            for technique in ClassicTechniques.all {
                if let hint = technique.findHint(in: state) {
                    foundHint = hint
                    break
                }
            }
            blackHole(foundHint)
        }
    }
}