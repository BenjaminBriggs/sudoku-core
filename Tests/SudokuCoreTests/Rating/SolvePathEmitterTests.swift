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

@Suite("Alternate solve paths")
struct AlternatePathTests {
    private func signature(_ path: SolvePathEmitter.SolvePath) -> [TechniqueID] {
        path.steps.map(\.technique).filter { $0.isSingle == false }.map(\.id)
    }

    @Test("A singles-only puzzle has no alternate path")
    func singlesOnly() {
        #expect(SolvePathEmitter.alternatives(from: RatedPuzzles.easy.grid).isEmpty)
    }

    @Test("Alternates solve, differ from the main path and each other, and come easiest first")
    func alternates() {
        let grid = RatedPuzzles.hardSwordfish.grid
        let main = SolvePathEmitter.emit(from: grid)
        let alternates = SolvePathEmitter.alternatives(from: grid)
        #expect(alternates.isEmpty == false)
        var signatures: Set<[TechniqueID]> = [signature(main)]
        for path in alternates {
            #expect(path.solved)
            #expect(path.finalState.grid == main.finalState.grid)
            #expect(signatures.insert(signature(path)).inserted, "each alternate differs beyond singles")
        }
        let ranks = alternates.map { path -> (PuzzleDifficulty.Level, Int) in
            let score = ScoreCalculator.compute(from: path)
            return (score.level, score.difficulty)
        }
        for (a, b) in zip(ranks, ranks.dropFirst()) {
            #expect(a <= b, "sorted by level then difficulty")
        }
    }

    @Test("An alternate can be lighter than the main path")
    func lighterAlternate() throws {
        // The main path through "Hard - Pointing+" costs 380 difficulty points; another costs less
        let grid = RatedPuzzles.hardSwordfish.grid
        let main = ScoreCalculator.compute(from: SolvePathEmitter.emit(from: grid))
        let lightest = try #require(SolvePathEmitter.alternatives(from: grid).first)
        let score = ScoreCalculator.compute(from: lightest)
        #expect(score.level <= main.level)
        #expect(score.difficulty < main.difficulty, "\(score.difficulty) vs \(main.difficulty)")
    }

    @Test("Every technique that applies is offered once, easiest first")
    func hintsInState() throws {
        let state = BoardState.fromGrid(RatedPuzzles.hardSwordfish.grid)
        let hints = HintFinder.hints(in: state)
        #expect(hints.isEmpty == false)
        #expect(hints.first?.technique == HintFinder.firstHint(in: state)?.technique)
        #expect(Set(hints.map(\.technique)).count == hints.count)
        #expect(hints.contains { $0.technique == .validation } == false)
        // In the order the technique array gives
        let order = ClassicTechniques.all.map(\.info)
        let positions = try hints.map { try #require(order.firstIndex(of: $0.technique)) }
        #expect(positions == positions.sorted())
    }

    @Test("A cancelled task gets what was found so far, without crashing")
    func cancellation() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return SolvePathEmitter.alternatives(from: RatedPuzzles.hardSwordfish.grid)
        }
        let paths = await task.value
        for path in paths { #expect(path.solved) }
    }
}
