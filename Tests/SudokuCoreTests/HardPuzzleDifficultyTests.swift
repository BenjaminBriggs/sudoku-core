import Foundation
import Testing

@testable import SudokuCore

private struct StoredPuzzle: Decodable {
    struct DifficultySnapshot: Decodable {
        let level: PuzzleDifficulty.Level
        let score: Int
        let hardestTechnique: String?
    }

    let difficulty: DifficultySnapshot
    let id: String?
    let solution: [[Int]]
    let startingState: [[Int]]
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        precondition(seed != 0, "Seed must be non-zero")
        state = seed
    }

    mutating func next() -> UInt64 {
        // Xoroshiro128** parameters
        var x = state
        x ^= x << 7
        x ^= x >> 9
        x ^= x << 8
        state = x
        return x
    }
}

@Suite("Hard Puzzle Regrading")
struct HardPuzzleDifficultyTests {

    @Test(
        "Specific hard puzzle examples remain hard",
        arguments: [
            "020005060890007003003000000300020006000000010407001005000104950000090000060000030",
            "009010030050009000000004020901000702030000100280060000020300609000090000000157004",
            "350000027002000300010000000600420003104500800800000605070640200000057000068900000",
            "000007000060003004907260000800600950000000016000000000025009030300080090008400600",
            "004960300007000000020000050130080000200700908040300500000000020000570000080041060",
            "000600204070000800900300170010002400002080000008095030003000000580000600604010000",
            "400010780000240005000009000000050010000800209000402300000080002840900060501000090",
            "001509080000200005007640010000000100000001002000000830060095300403080090700000050",
            "176000008025640100000001060081050000040036970000914002200000010700003400600070005",
            "000000002000005740710940080008000005060000004020700060000000006189300000000800920",
        ]
    )
    func specificHardPuzzlesRemainHard(puzzleString: String) throws {
        // Parse puzzle string into grid
        let grid = Solution.cells(from: puzzleString)

        do {
            let result = try SudokuDifficultyCalculator.calculateDifficultySync(for: grid)

            #expect(
                result.level == .hard || result.level == .expert,
                "Puzzle should be hard or expert (score: \(Int(result.score)), level: \(result.level.rawValue), hardest: \(result.hardestTechnique?.rawValue ?? "unknown"))"
            )

            #expect(
                result.score >= 600,
                "Hard puzzle should have score >= 600, got \(Int(result.score))"
            )
        } catch {
            // Expected for puzzles requiring unimplemented techniques
            Issue.record(
                Comment(
                    rawValue:
                        "Puzzle \(puzzleString.prefix(20))... could not be solved with current techniques"
                ))
            throw error
        }
    }
}
