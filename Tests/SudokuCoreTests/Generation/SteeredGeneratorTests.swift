import Testing
@testable import SudokuCore

struct SteeredGeneratorTests {
    @Test("Steered puzzles rate at the level asked for", arguments: [PuzzleDifficulty.Level.easy, .medium, .hard])
    func reachesLevel(_ level: PuzzleDifficulty.Level) throws {
        // Easy to Hard land almost every time; allow a few solutions for an unlucky one
        let steered = try #require(
            (0..<5).lazy.compactMap { _ in SudokuGenerator.createPuzzle(level: level) }.first
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

    @Test("Steered puzzles keep the symmetry", arguments: [Symmetry.rotational180, .rotational90, .diagonal])
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
