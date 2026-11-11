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

@Suite("Paired solve paths")
struct PairedPathTests {
    typealias SolvePath = SolvePathEmitter.SolvePath

    /// Whether two paths make the same deductions in the same order and end in the same state.
    /// A step's actions are compared as a set: solving the same grid twice can list one step's
    /// actions in a different order, so `==` on paths is stricter than "the same path".
    private func sameDeductions(_ a: SolvePath, _ b: SolvePath) -> Bool {
        func deductions(_ path: SolvePath) -> [[String]] {
            path.steps.map { [$0.technique.id.rawValue] + $0.actions.map { String(describing: $0) }.sorted() }
        }
        return deductions(a) == deductions(b) && a.solved == b.solved
            && a.iterationCount == b.iterationCount && a.finalState == b.finalState
    }

    /// The path in HoDoKu's order, solved on its own.
    private func hodokuPath(of grid: [[Int]], maxIterations: Int = 300) -> SolvePathEmitter.SolvePath {
        SolvePathEmitter.emit(from: grid, maxIterations: maxIterations) { state in
            HoDoKuCalculator.techniques.lazy.compactMap { $0.findHint(in: state) }.first
        }
    }

    private func pair(_ grid: [[Int]], maxIterations: Int = 300)
        -> (first: SolvePathEmitter.SolvePath, second: SolvePathEmitter.SolvePath)
    {
        SolvePathEmitter.emitPair(
            from: grid, first: ClassicTechniques.all, second: HoDoKuCalculator.techniques,
            maxIterations: maxIterations)
    }

    @Test("Paths solved together are the paths solved apart", arguments: CorpusPuzzle.selected)
    func pairedPathsMatch(_ puzzle: CorpusPuzzle) {
        let paths = pair(puzzle.startingState)
        #expect(sameDeductions(paths.first, SolvePathEmitter.emit(from: puzzle.startingState)))
        #expect(sameDeductions(paths.second, hodokuPath(of: puzzle.startingState)))
    }

    @Test("Paired paths stall, and stop at the cap, where the paths apart do")
    func pairedPathsStallAndStop() {
        let puzzle = RatedPuzzles.hardSwordfish.grid
        // With a clue out there are several solutions, so both paths stall
        var stalling = puzzle
        let clue = Puzzle.Index.allIndices.first { stalling[$0.row][$0.column] != 0 }!
        stalling[clue.row][clue.column] = 0
        #expect(Validator.solutionCount(of: stalling).isUnique == false)

        for (grid, cap) in [(stalling, 300), (puzzle, 3), (puzzle, 20), (Puzzle.example().solution, 300)] {
            let paths = pair(grid, maxIterations: cap)
            #expect(sameDeductions(paths.first, SolvePathEmitter.emit(from: grid, maxIterations: cap)))
            #expect(sameDeductions(paths.second, hodokuPath(of: grid, maxIterations: cap)))
        }
    }

    @Test("Paired paths part where the two orders pick different techniques")
    func pairedPathsPart() {
        // The same technique list twice never parts the paths; the list and its reverse part
        // them at the first state where more than one technique applies.
        let grid = RatedPuzzles.hardSwordfish.grid
        let same = SolvePathEmitter.emitPair(
            from: grid, first: ClassicTechniques.all, second: ClassicTechniques.all)
        #expect(same.first == same.second)
        #expect(sameDeductions(same.first, SolvePathEmitter.emit(from: grid)))

        let reversed = Array(ClassicTechniques.all.reversed())
        let apart = SolvePathEmitter.emitPair(from: grid, first: ClassicTechniques.all, second: reversed)
        #expect(sameDeductions(apart.first, SolvePathEmitter.emit(from: grid)))
        #expect(sameDeductions(apart.second, SolvePathEmitter.emit(from: grid) { state in
            reversed.lazy.compactMap { $0.findHint(in: state) }.first
        }))
        #expect(apart.first.steps.map(\.technique.id) != apart.second.steps.map(\.technique.id))
    }

    @Test("The rating and its path are the ones worked out apart", arguments: CorpusPuzzle.selected)
    func ratedPathMatches(_ puzzle: CorpusPuzzle) throws {
        let rated = try SudokuDifficultyCalculator.ratedPath(for: puzzle.startingState)
        #expect(sameDeductions(rated.path, SolvePathEmitter.emit(from: puzzle.startingState)))
        #expect(rated.result == (try SudokuDifficultyCalculator.calculateDifficulty(for: puzzle.startingState)))
        // The HoDoKu estimate is the one a solve in HoDoKu's order alone gives
        let hodoku = HoDoKuCalculator.compute(for: puzzle.startingState)
        #expect(rated.result.hodokuRating == hodoku?.score)
        #expect(rated.result.hodokuLevel == hodoku?.level)
    }
}
