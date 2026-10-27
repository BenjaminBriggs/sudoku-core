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

/// Where the hint finder stalls on Professional seed 086070004…: the grid and every empty
/// cell's candidates at that point.
private func stallState() -> BoardState {
    let grid = parseGrid("086070004010080006425196378590007000630805000048009050070928005069051007850760009")
    let candidates = "39,,,35,,23,1259,129,,379,,37,345,,234,259,29,,,,,,,,,,,,,12,26,134,,468,468,123,,,127,,14,,479,49,12,127,,,26,13,,67,,123,13,,134,,,,146,1346,,23,,,34,,,248,2348,,,,1234,,,34,124,1234,"
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { Set($0.compactMap { Int(String($0)) }) }
    return BoardState(
        grid: grid,
        pencilMarks: (0..<9).map { r in Array(candidates[(r * 9)..<(r * 9 + 9)]) },
        validOptions: Validator.validOptions(for: grid),
        assumesUniqueSolution: true
    )
}

// MARK: - Individual Technique Benchmarks

let hintFinderBenchmarks: @Sendable () -> Void = {
    // Naked Single - simplest technique
    Benchmark("HintFinder.NakedSingle") { benchmark in
        let grid = parseGrid("000000000000000000000000000000000000000000283000000154000000000000000070000000090")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.nakedSingle, in: state)  // 'await' makes closure async
            blackHole(hint)
        }
    }

    // Hidden Single
    Benchmark("HintFinder.HiddenSingle") { benchmark in
        let grid = parseGrid("000093000000005000000064000000000000000000000000000000000000000000700000000000000")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.hiddenSingle, in: state)
            blackHole(hint)
        }
    }

    // Naked Pair
    Benchmark("HintFinder.NakedPair") { benchmark in
        let grid = parseGrid("658003421249185003713006598802030150037000286005800000586010042971000805324008017")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.nakedPair, in: state)
            blackHole(hint)
        }
    }

    // Naked Triple
    Benchmark("HintFinder.NakedTriple") { benchmark in
        let grid = parseGrid("631480000000130806008960134006079000800256000570041600060518749985724361147693582")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.nakedTriple, in: state)
            blackHole(hint)
        }
    }

    // X-Wing - expensive fish pattern
    Benchmark("HintFinder.XWing") { benchmark in
        let grid = parseGrid("040070180003100700170948035617890350009000071000701908791486523004017896068009417")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.xWing, in: state)
            blackHole(hint)
        }
    }

    // Swordfish - more expensive fish pattern
    Benchmark("HintFinder.Swordfish") { benchmark in
        let grid = parseGrid("638005219149628000752193800820951030573860901000030508300509602265380190007216000")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.swordfish, in: state)
            blackHole(hint)
        }
    }

    // XY-Wing
    Benchmark("HintFinder.XYWing") { benchmark in
        let grid = parseGrid("387956412600024083420800096743519628162487935958002147200098354500240800804005200")
        let state = createBoardState(from: grid)
        for _ in benchmark.scaledIterations {
            let hint = HintFinder.findHint(for:.xyWing, in: state)
            blackHole(hint)
        }
    }

    // Each technique searching a Professional seed's stall point, where nothing applies, so
    // every finder runs its whole search. The n-Y-Wings are the ones to watch.
    for technique in [HintTechnique.crane, .uniqueRectangleType1, .uniqueRectangleType3, .bug,
                      .fourYWing, .fiveYWing, .sixYWing, .sevenYWing, .finnedJellyfish] {
        Benchmark("HintFinder.Stall.\(technique.rawValue)") { benchmark in
            let state = stallState()
            for _ in benchmark.scaledIterations {
                blackHole(HintFinder.findHint(for: technique, in: state))
            }
        }
    }

    // Full hint search - tries all techniques in order
    Benchmark("HintFinder.FullSearch-Easy", configuration: .init(metrics: [.wallClock, .cpuUser, .throughput])) { benchmark in
        let grid = parseGrid("000000000000000000000000000000000000000000283000000154000000000000000070000000090")
        let state = createBoardState(from: grid)

        for _ in benchmark.scaledIterations {
            var foundHint: HintStep? = nil
            for technique in HintTechnique.orderedCases {
                if let hint = HintFinder.findHint(for: technique, in: state) {
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
            for technique in HintTechnique.orderedCases {
                if let hint = HintFinder.findHint(for: technique, in: state) {
                    foundHint = hint
                    break
                }
            }
            blackHole(foundHint)
        }
    }
}