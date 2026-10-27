import Testing
@testable import SudokuCore

struct SteeredGeneratorTests {
    /// The first puzzle `make` finds in `tries`. Not `lazy.compactMap { }.first`: that calls
    /// the closure twice per element, and a random generator can return nil the second time.
    private static func firstFound(tries: Int, _ make: () -> SteeredPuzzle?) -> SteeredPuzzle? {
        for _ in 0..<tries {
            if let found = make() { return found }
        }
        return nil
    }

    @Test("Steered puzzles rate at the level asked for", arguments: [PuzzleDifficulty.Level.easy, .medium, .hard])
    func reachesLevel(_ level: PuzzleDifficulty.Level) throws {
        // Easy to Hard land almost every time; allow a few solutions for an unlucky one
        let steered = try #require(
            Self.firstFound(tries: 5) { SudokuGenerator.createPuzzle(level: level) }
        )
        let rerated = try SudokuDifficultyCalculator.calculateDifficulty(for: steered.puzzle.startingState)
        #expect(steered.matchesLevel)
        #expect(rerated.level == level)
        #expect(steered.puzzle.difficulty.level == level)
        #expect(rerated.needsGuessing == false)
        #expect(Validator.solutionCount(of: steered.puzzle.startingState).isUnique)
    }

    @Test("Steered puzzles are clues of the solution they came from")
    func cluesComeFromSolution() throws {
        let solution = SolutionGenerator.generateRandomSolution()
        let steered = try #require(SudokuGenerator.createPuzzle(level: .medium, from: solution, bestEffort: true))
        #expect(steered.puzzle.solution == solution)
        for index in Puzzle.Index.allIndices {
            let clue = steered.puzzle.startingState[index.row][index.column]
            #expect(clue == 0 || clue == solution[index.row][index.column])
        }
    }

    @Test("Steered puzzles keep the symmetry", arguments: [Symmetry.rotational180, .rotational90, .diagonal, .orthogonal, .diagonals])
    func keepsSymmetry(_ symmetry: Symmetry) throws {
        let steered = try #require(SudokuGenerator.createPuzzle(level: .hard, symmetry: symmetry, bestEffort: true))
        #expect(symmetry.isSatisfied(by: steered.puzzle.startingState))
        #expect(Validator.solutionCount(of: steered.puzzle.startingState).isUnique)
    }

    @Test("The rating budget bounds the work")
    func ratingBudget() {
        for _ in 0..<5 {
            guard let steered = SudokuGenerator.createPuzzle(level: .expert, maxRatings: 6, bestEffort: true) else {
                continue
            }
            #expect(steered.ratings <= 6)
        }
    }

    @Test("Without best effort a missed level returns nil, never a wrong-level puzzle")
    func missedLevelIsNil() {
        // One rating can't search; whatever comes back must still be the level asked for
        for _ in 0..<5 {
            if let steered = SudokuGenerator.createPuzzle(level: .expert, maxRatings: 1) {
                #expect(steered.matchesLevel)
                #expect(steered.result.level == .expert)
            }
        }
    }

    @Test("Best effort reports a missed level")
    func bestEffortReportsMiss() throws {
        let steered = try #require(SudokuGenerator.createPuzzle(level: .professional, maxRatings: 2, bestEffort: true))
        #expect(steered.matchesLevel == PuzzleDifficulty.Level.professional.scoreRange.contains(Int(steered.result.score)))
        #expect(steered.result.needsGuessing == false)
    }

    @Test("A cancelled task gets nil")
    func cancellation() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return SudokuGenerator.createPuzzle(level: .hard, bestEffort: true)
        }
        #expect(await task.value == nil)
    }

    @Test("Score ranges cover every score once, matching the calculator's levels")
    func scoreRanges() {
        let levels = PuzzleDifficulty.Level.allCases
        for score in [0, 1, 300, 301, 600, 601, 1000, 1001, 1600, 1601, 2000, 2001, 9000] {
            #expect(levels.filter { $0.scoreRange.contains(score) }.count == 1)
        }
        #expect(PuzzleDifficulty.Level.expert.scoreRange == 1001...1600)
        #expect(PuzzleDifficulty.Level.professional.scoreRange == 1601...2000)
    }

    // MARK: - Clue count

    private static func clues(_ grid: [[Int]]) -> Int {
        grid.joined().count { $0 != 0 }
    }

    @Test("A clue range keeps the puzzle's clue count in it", arguments: [26...30, 31...40])
    func cluesInRange(_ givens: ClosedRange<Int>) throws {
        let steered = try #require(
            Self.firstFound(tries: 10) { SudokuGenerator.createPuzzle(level: .medium, givens: givens) }
        )
        #expect(givens.contains(Self.clues(steered.puzzle.startingState)))
        #expect(steered.result.level == .medium)
    }

    @Test("A range below any minimal puzzle is a clue miss, with no rating spent")
    func unreachableRangeIsGivensMiss() {
        // No minimal puzzle has fewer than 17 clues
        let result = SudokuGenerator.steerPuzzle(level: .medium, givens: 0...16)
        guard case .failure(let miss) = result else {
            Issue.record("Found a 16-clue puzzle")
            return
        }
        #expect(miss == .givens)
    }

    @Test("Too many clues for the level is a clue miss")
    func tooManyCluesForLevel() {
        // Expert needs far fewer than 60 clues
        for _ in 0..<3 {
            let result = SudokuGenerator.steerPuzzle(level: .expert, givens: 60...70)
            guard case .failure(let miss) = result else {
                Issue.record("Found an Expert puzzle with 60+ clues")
                return
            }
            #expect(miss == .givens)
        }
    }

    @Test("Best effort stays in the clue range")
    func bestEffortInRange() throws {
        for _ in 0..<3 {
            let steered = try #require(
                SudokuGenerator.createPuzzle(level: .expert, givens: 28...32, maxRatings: 10, bestEffort: true))
            #expect((28...32).contains(Self.clues(steered.puzzle.startingState)))
        }
    }
}

struct PuzzleCreatorLevelTests {
    /// The old implementation labelled by HoDoKu score but aimed at hardest-technique ranges,
    /// so `.easy` came back Medium or harder.
    @Test("createPuzzleWithDifficulty returns the calculator's level", arguments: [PuzzleDifficulty.Level.easy, .medium, .hard])
    func returnsRequestedLevel(_ level: PuzzleDifficulty.Level) async throws {
        let puzzle = try await PuzzleCreator.createPuzzleWithDifficulty(level, maxAttempts: 10)
        let rerated = try SudokuDifficultyCalculator.calculateDifficulty(for: puzzle.startingState)
        #expect(puzzle.difficulty.level == level)
        #expect(rerated.level == level)
        #expect(rerated.needsGuessing == false)
    }
}

struct DifficultyMeasurementTests {
    private func result(_ techniques: [HintTechnique]) -> SudokuDifficultyCalculator.DifficultyResult {
        .init(level: .hard, score: 700, techniquesUsed: techniques, iterationCount: techniques.count, wasSolved: true)
    }

    @Test("Guessing is the .unknown marker")
    func needsGuessing() {
        #expect(result([.nakedSingle, .unknown]).needsGuessing)
        #expect(result([.nakedSingle, .xWing]).needsGuessing == false)
    }

    @Test("Hardest technique count counts its steps")
    func hardestCount() {
        #expect(result([.nakedSingle, .xWing, .hiddenSingle, .xWing, .nakedPair]).hardestTechniqueCount == 2)
        #expect(result([.nakedSingle, .xWing, .unknown]).hardestTechniqueCount == 1)
        #expect(result([]).hardestTechniqueCount == 0)
    }

    @Test("What follows the last hardest step")
    func afterHardest() {
        #expect(result([.nakedPair, .xWing, .nakedSingle, .hiddenSingle]).hardestTechniqueAfterLastHardestStep == .hiddenSingle)
        #expect(result([.xWing, .nakedPair, .xWing, .nakedPair, .nakedSingle]).hardestTechniqueAfterLastHardestStep == .nakedPair)
        #expect(result([.nakedSingle, .xWing]).hardestTechniqueAfterLastHardestStep == nil)
        #expect(result([.xWing, .nakedSingle, .unknown]).hardestTechniqueAfterLastHardestStep == .nakedSingle)
    }

}
