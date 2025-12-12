import Testing
@testable import SudokuCore

@Suite("SolvePathEmitter")
struct SolvePathEmitterTests {
    // Classic solved grid
    private var solved: [[Int]] {[
        [5,3,4,6,7,8,9,1,2],
        [6,7,2,1,9,5,3,4,8],
        [1,9,8,3,4,2,5,6,7],
        [8,5,9,7,6,1,4,2,3],
        [4,2,6,8,5,3,7,9,1],
        [7,1,3,9,2,4,8,5,6],
        [9,6,1,5,3,7,2,8,4],
        [2,8,7,4,1,9,6,3,5],
        [3,4,5,2,8,6,1,7,9]
    ]}

    @Test("Emits a single naked single step and solves")
    func emitsSingleStepForAlmostSolvedBoard() {
        var grid = solved
        grid[8][8] = 0 // one empty cell -> naked single

        let path = SolvePathEmitter.emit(from: grid)
        #expect(path.solved == true)
        #expect(path.steps.count == 1)
        #expect(path.steps.first?.technique == .nakedSingle)
        #expect(path.finalState.grid[8][8] == 9)
        #expect(path.iterationCount >= 1)
    }

    @Test("Deterministic emission: same puzzle yields identical steps")
    func deterministicEmission() {
        var grid = solved
        grid[8][8] = 0
        let p1 = SolvePathEmitter.emit(from: grid)
        let p2 = SolvePathEmitter.emit(from: grid)
        #expect(p1.steps == p2.steps)
        #expect(p1.solved == p2.solved)
        #expect(p1.finalState.grid == p2.finalState.grid)
    }
}
