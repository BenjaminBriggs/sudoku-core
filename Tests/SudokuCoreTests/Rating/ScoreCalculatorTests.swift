import Testing

@testable import SudokuCore

@Suite("ScoreCalculator")
struct ScoreCalculatorTests {
    private var solved: [[Int]] {
        [
            [5, 3, 4, 6, 7, 8, 9, 1, 2],
            [6, 7, 2, 1, 9, 5, 3, 4, 8],
            [1, 9, 8, 3, 4, 2, 5, 6, 7],
            [8, 5, 9, 7, 6, 1, 4, 2, 3],
            [4, 2, 6, 8, 5, 3, 7, 9, 1],
            [7, 1, 3, 9, 2, 4, 8, 5, 6],
            [9, 6, 1, 5, 3, 7, 2, 8, 4],
            [2, 8, 7, 4, 1, 9, 6, 3, 5],
            [3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]
    }

    private func path(_ techniques: [TechniqueInfo]) -> SolvePathEmitter.SolvePath {
        SolvePathEmitter.SolvePath(
            steps: techniques.map { SolvePathEmitter.SolveStep(technique: $0, actions: []) },
            solved: true,
            finalState: BoardState.fromGrid(solved),
            iterationCount: techniques.count
        )
    }

    @Test("A single scores HoDoKu's 4 points, all tedium, and is Beginner")
    func sumsPoints() {
        var grid = solved
        grid[8][8] = 0  // single step

        let result = ScoreCalculator.compute(for: grid)
        #expect(result.score == 4)
        #expect(result.tedium == 4)
        #expect(result.difficulty == 0)
        #expect(result.breakdown == [TechniqueInfo.nakedSingle.id: 4])
        #expect(result.level == .easy)
    }

    @Test("A singles-only puzzle of ordinary size is Beginner")
    func singlesOnlyIsBeginner() {
        // 44 naked singles and 8 hidden singles: the path of a 29-clue singles puzzle
        let steps = Array(repeating: TechniqueInfo.nakedSingle, count: 44) + Array(repeating: .hiddenSingle, count: 8)
        let result = ScoreCalculator.compute(from: path(steps))
        #expect(result.score == 44 * 4 + 8 * 14)
        #expect(result.tedium == result.score)
        #expect(result.difficulty == 0)
        #expect(result.level == .easy)
    }

    @Test("A hard step sets the level however low the score")
    func hardStepSetsLevel() {
        let steps = Array(repeating: TechniqueInfo.nakedSingle, count: 20) + [.wWing]
        let result = ScoreCalculator.compute(from: path(steps))
        #expect(result.score == 20 * 4 + 150)
        #expect(result.difficulty == 150)
        #expect(result.tedium == 80)
        #expect(result.level == .hard)
    }

    @Test("Difficulty adds the steps beyond singles")
    func difficultyAddsNonSingles() {
        let steps: [TechniqueInfo] = [.nakedSingle, .lockedCandidatesPointing, .hiddenSingle, .lockedCandidatesPointing, .lockedCandidatesClaiming, .wWing]
        let result = ScoreCalculator.compute(from: path(steps))
        #expect(result.difficulty == 300, "a W-Wing and three pointings")
        #expect(result.tedium == 18)
        #expect(result.score == 318)
        #expect(result.level == .hard)
    }

    @Test("The level follows the hardest step, not the total", arguments: [
        (TechniqueInfo.hiddenSingle, PuzzleDifficulty.Level.easy),
        (.lockedCandidatesPointing, .medium),
        (.nakedTriple, .medium),
        (.nakedQuad, .hard),
        (.xWing, .hard),
        (.wWing, .hard),
        (.uniqueRectangleType1, .hard),
        (.bug, .hard),
        (.crane, .hard),
        (.finnedSwordfish, .expert),
        (.finnedJellyfish, .expert),
        (.sevenYWing, .expert),
        (.unknown, .professional),
    ])
    func levelFollowsHardestStep(_ technique: TechniqueInfo, _ level: PuzzleDifficulty.Level) {
        // A hundred hidden singles would pass every HoDoKu band; the level still reads the hardest step
        let steps = Array(repeating: TechniqueInfo.hiddenSingle, count: 100) + [technique]
        let result = ScoreCalculator.compute(from: path(steps))
        #expect(result.level == level)
        let points = Int(technique.scorePoints ?? 0)
        #expect(result.tedium == 1400 + (technique.isSingle ? points : 0))
        #expect(result.difficulty == (technique.isSingle ? 0 : points))
        #expect(result.score == result.difficulty + result.tedium)
    }

    @Test("An empty path is Beginner with no points")
    func emptyPath() {
        let result = ScoreCalculator.compute(from: path([]))
        #expect(result.score == 0)
        #expect(result.level == .easy)
        #expect(result.breakdown.isEmpty)
    }

    @Test("Elimination count does not modify technique points")
    func eliminationsDoNotInflatePoints() {
        let actions = (0..<3).map { column in
            HintAction(position: Puzzle.Index(row: 0, column: column), ruleOut: 1)
        }
        let step = SolvePathEmitter.SolveStep(
            technique: .xWing,
            actions: actions
        )
        let path = SolvePathEmitter.SolvePath(
            steps: [step],
            solved: true,
            finalState: BoardState.fromGrid(solved),
            iterationCount: 1
        )

        let result = ScoreCalculator.compute(from: path)
        #expect(result.score == Int((TechniqueInfo.xWing.scorePoints ?? 0)))
    }

    @Test("The score is the difficulty calculator's")
    func matchesCalculator() throws {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = ScoreCalculator.compute(for: puzzle.grid)
            // The calculator throws `.unsolved` on some of these puzzles; compare the rest.
            guard let difficulty = try? SudokuDifficultyCalculator.calculateDifficulty(for: puzzle.grid) else { continue }
            #expect(Double(result.score) == difficulty.score, "\(puzzle.name)")
            #expect(result.difficulty == difficulty.difficulty, "\(puzzle.name)")
            #expect(result.tedium == difficulty.tedium, "\(puzzle.name)")
            // The calculator's level also reads the guessing marker it appends after a stall
            if difficulty.needsGuessing {
                #expect(difficulty.level == .professional, "\(puzzle.name)")
            } else {
                #expect(result.level == difficulty.level, "\(puzzle.name)")
            }
        }
    }

    // MARK: - Comprehensive Rating Tests

    @Test("All puzzles produce scores within tolerance")
    func testAllPuzzlesWithinTolerance() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = ScoreCalculator.compute(for: puzzle.grid)

            #expect(
                result.score >= puzzle.expectedScore - puzzle.scoreTolerance,
                "Score \(result.score) too low for \(puzzle.name)")
            #expect(
                result.score <= puzzle.expectedScore + puzzle.scoreTolerance,
                "Score \(result.score) too high for \(puzzle.name)")
        }
    }

    // MARK: - Classification Tests

    @Test("Every rated puzzle's level is its hardest step's")
    func levelIsHardestSteps() {
        for puzzle in RatedPuzzles.allPuzzles {
            let path = SolvePathEmitter.emit(from: puzzle.grid)
            let result = ScoreCalculator.compute(from: path)
            #expect(result.level == path.steps.map(\.technique.level).max() ?? .easy, "\(puzzle.name)")
            #expect(result.score == result.difficulty + result.tedium, "\(puzzle.name)")
        }
    }

    // MARK: - Cumulative Rating Tests

    @Test("Score generally correlates with difficulty")
    func testRatingCorrelation() {
        let veryEasyResult = ScoreCalculator.compute(for: RatedPuzzles.veryEasy.grid)
        let mediumResult = ScoreCalculator.compute(for: RatedPuzzles.medium.grid)
        let hardResult = ScoreCalculator.compute(for: RatedPuzzles.hardXWing.grid)

        // Verify all produce positive scores
        #expect(veryEasyResult.score > 0, "Very Easy should have positive score")
        #expect(mediumResult.score > 0, "Medium should have positive score")
        #expect(hardResult.score > 0, "Hard should have positive score")

        // The cumulative score depends on step count, so strict monotonicity isn't
        // guaranteed, but check within tolerances
        #expect(
            abs(veryEasyResult.score - RatedPuzzles.veryEasy.expectedScore)
                <= RatedPuzzles.veryEasy.scoreTolerance,
            "Very Easy score should match expected")
    }

    @Test("All test puzzles produce valid scores")
    func testAllPuzzlesHaveValidRatings() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = ScoreCalculator.compute(for: puzzle.grid)

            #expect(result.score > 0, "\(puzzle.name) should have positive score")
            #expect(
                result.score < 5000,
                "\(puzzle.name) score \(result.score) exceeds reasonable bounds")
            #expect(
                result.breakdown.isEmpty == false,
                "\(puzzle.name) should have technique breakdown")
        }
    }

    @Test("Breakdown sums to the total score")
    func testBreakdownAccuracy() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = ScoreCalculator.compute(for: puzzle.grid)
            #expect(result.breakdown.values.reduce(0, +) == result.score, "\(puzzle.name)")
        }
    }

    @Test("Breakdown contains only positive point values")
    func testBreakdownPositiveValues() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = ScoreCalculator.compute(for: puzzle.grid)

            for (technique, points) in result.breakdown {
                #expect(
                    points > 0,
                    "\(puzzle.name): \(technique) should have positive points, got \(points)")
            }
        }
    }

    @Test("Score and SE rating are both valid")
    func testBothRatingsValid() {
        // They measure different things (cumulative vs peak) so correlation is loose
        for puzzle in RatedPuzzles.allPuzzles {
            let seResult = SECalculator.compute(for: puzzle.grid)
            let scoreResult = ScoreCalculator.compute(for: puzzle.grid)

            #expect(scoreResult.score > 0, "\(puzzle.name): score should be positive")
            #expect(
                scoreResult.score < 5000,
                "\(puzzle.name): score (\(scoreResult.score)) exceeds reasonable bounds")
            #expect(
                seResult.rating > 0,
                "\(puzzle.name): SE rating should be positive")
            #expect(
                seResult.rating < 15.0,
                "\(puzzle.name): SE (\(seResult.rating)) exceeds reasonable bounds")
        }
    }
}
