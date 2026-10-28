import Testing
@testable import SudokuCore

@Suite("Hint Regression Tests")
struct HintRegressionTests {
    @Test("Applying hints should not empty candidates of unsolved cells")
    func testHintsDoNotEraseAllCandidates() throws {
        // Known hard puzzle that previously exposed solver regressions
        let puzzle = "020005060890007003003000000300020006000000010407001005000104950000090000060000030"
        var state = try makeInitialState(from: puzzle)

        var lastHint: TechniqueInfo? = nil
        for iteration in 0..<300 {
            assertNoEmptyCandidates(in: state, iteration: iteration, previousHint: lastHint)

            guard let hint = nextHint(for: state) else {
                break
            }

            lastHint = hint.technique
            state = applyHint(hint, to: state)
            assertNoEmptyCandidates(in: state, iteration: iteration, previousHint: lastHint)
        }
    }

    @Test("applying(_:) matches a full candidate recompute at every solve step")
    func testApplyingMatchesFullRecompute() throws {
        let puzzle = "020005060890007003003000000300020006000000010407001005000104950000090000060000030"
        var state = try makeInitialState(from: puzzle)

        for _ in 0..<300 {
            guard let hint = nextHint(for: state) else { break }
            state = state.applying(hint)

            let recomputed = Validator.validOptions(for: state.grid)
            #expect(
                state.validOptions == recomputed,
                "validOptions after applying \(hint.technique.rawValue) should match a full recompute"
            )
            for row in 0..<9 {
                for col in 0..<9 where state.grid[row][col] == 0 {
                    #expect(
                        state.pencilMarks[row][col].isSubset(of: recomputed[row][col]),
                        "pencilMarks must stay within valid options at (\(row),\(col))"
                    )
                }
            }
        }
    }
}

private func makeInitialState(from puzzle: String) throws -> BoardState {
    #expect(puzzle.count == 81, "Unexpected puzzle length")

    var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    for (index, character) in puzzle.enumerated() {
        let value = Int(String(character)) ?? 0
        grid[index / 9][index % 9] = value
    }

    return BoardState.fromGrid(grid)
}

private func nextHint(for state: BoardState) -> HintStep? {
    HintFinder.firstHint(in: state)
}

private func applyHint(_ hint: HintStep, to state: BoardState) -> BoardState {
    state.applying(hint)
}

private func assertNoEmptyCandidates(in state: BoardState, iteration: Int, previousHint: TechniqueInfo?) {
    for row in 0..<9 {
        for col in 0..<9 where state.grid[row][col] == 0 {
            let candidates = state.pencilMarks[row][col]
            let message: String
            if let technique = previousHint {
                message = "Iteration \(iteration): cell (\(row + 1),\(col + 1)) lost all candidates after applying \(technique.rawValue)"
            } else {
                message = "Iteration \(iteration): cell (\(row + 1),\(col + 1)) lost all candidates"
            }
            #expect(candidates.isEmpty == false, Comment(rawValue: message))
        }
    }
}
