import Testing
@testable import SudokuCore

@Suite("Hint Regression Tests")
struct HintRegressionTests {
    @Test("Applying hints should not empty candidates of unsolved cells")
    func testHintsDoNotEraseAllCandidates() throws {
        // Known hard puzzle that previously exposed solver regressions
        let puzzle = "020005060890007003003000000300020006000000010407001005000104950000090000060000030"
        var state = try makeInitialState(from: puzzle)

        var lastHint: HintTechnique? = nil
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

private func assertNoEmptyCandidates(in state: BoardState, iteration: Int, previousHint: HintTechnique?) {
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
