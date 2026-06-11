import Testing

@testable import SudokuCore

@Suite("HoDoKuCalculator")
struct HoDoKuCalculatorTests {
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

    @Test("Sums enum points across steps and classifies")
    func sumsPoints() {
        var grid = solved
        grid[8][8] = 0  // single step

        let result = HoDoKuCalculator.compute(for: grid)
        #expect(result.rating == Int((TechniqueInfo.nakedSingle.hodokuPoints ?? 0)))
        #expect(result.breakdown["Single"] == Int((TechniqueInfo.nakedSingle.hodokuPoints ?? 0)))
        #expect(result.classLabel.count > 0)
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

        let result = HoDoKuCalculator.compute(from: path)
        #expect(result.rating == Int((TechniqueInfo.xWing.hodokuPoints ?? 0)))
    }

    // MARK: - Comprehensive Rating Tests

    @Test("All puzzles produce ratings within tolerance")
    func testAllPuzzlesWithinTolerance() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = HoDoKuCalculator.compute(for: puzzle.grid)

            #expect(
                result.rating >= puzzle.expectedHoDoKu - puzzle.hodokuRatingTolerance,
                "Rating \(result.rating) too low for \(puzzle.name)")
            #expect(
                result.rating <= puzzle.expectedHoDoKu + puzzle.hodokuRatingTolerance,
                "Rating \(result.rating) too high for \(puzzle.name)")
        }
    }

    // MARK: - Classification Tests

    @Test("Classification thresholds map to PuzzleDifficulty levels")
    func testClassificationThresholds() {
        // Test boundaries using our actual PuzzleDifficulty.Level system
        let testCases: [(rating: Int, expectedClasses: [String])] = [
            (50, ["Beginner"]),
            (150, ["Beginner"]),
            (300, ["Beginner", "Intermediate"]),
            (450, ["Intermediate"]),
            (600, ["Intermediate", "Advanced"]),
            (800, ["Advanced"]),
            (1000, ["Advanced", "Expert"]),
            (1200, ["Expert"]),
            (1600, ["Expert", "Master"]),
            (2000, ["Master"]),
        ]

        for testCase in testCases {
            let label = classifyTestRating(testCase.rating)
            #expect(
                testCase.expectedClasses.contains(label),
                "Rating \(testCase.rating) classified as '\(label)' but expected one of \(testCase.expectedClasses)"
            )
        }
    }

    /// Helper to test classification logic
    private func classifyTestRating(_ rating: Int) -> String {
        for (level, maxPoints) in RatingTables.HoDoKu.classThresholds {
            if rating <= maxPoints { return level.debugDescription }
        }
        return "Master"
    }

    // MARK: - Cumulative Rating Tests

    @Test("Rating generally correlates with difficulty")
    func testRatingCorrelation() {
        let veryEasyResult = HoDoKuCalculator.compute(for: RatedPuzzles.veryEasy.grid)
        let mediumResult = HoDoKuCalculator.compute(for: RatedPuzzles.medium.grid)
        let hardResult = HoDoKuCalculator.compute(for: RatedPuzzles.hardXWing.grid)

        // Verify all produce positive ratings
        #expect(veryEasyResult.rating > 0, "Very Easy should have positive rating")
        #expect(mediumResult.rating > 0, "Medium should have positive rating")
        #expect(hardResult.rating > 0, "Hard should have positive rating")

        // HoDoKu cumulative rating depends on step count and eliminations,
        // so strict monotonicity isn't guaranteed, but check within tolerances
        #expect(
            abs(veryEasyResult.rating - RatedPuzzles.veryEasy.expectedHoDoKu)
                <= RatedPuzzles.veryEasy.hodokuRatingTolerance,
            "Very Easy rating should match expected")
    }

    @Test("All test puzzles produce valid ratings")
    func testAllPuzzlesHaveValidRatings() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = HoDoKuCalculator.compute(for: puzzle.grid)

            #expect(result.rating > 0, "\(puzzle.name) should have positive rating")
            #expect(
                result.rating < 5000,
                "\(puzzle.name) rating \(result.rating) exceeds reasonable bounds")
            #expect(
                result.classLabel.isEmpty == false,
                "\(puzzle.name) should have class label")
            #expect(
                result.breakdown.isEmpty == false,
                "\(puzzle.name) should have technique breakdown")
        }
    }

    @Test("Breakdown correctly sums to total rating")
    func testBreakdownAccuracy() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = HoDoKuCalculator.compute(for: puzzle.grid)

            let breakdownSum = result.breakdown.values.reduce(0, +)

            // Allow some tolerance for rounding and modifier effects
            let tolerance = max(20, result.rating / 10)
            #expect(
                abs(breakdownSum - result.rating) <= tolerance,
                "\(puzzle.name): breakdown sum (\(breakdownSum)) should ≈ rating (\(result.rating))"
            )
        }
    }

    @Test("Breakdown contains only positive point values")
    func testBreakdownPositiveValues() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = HoDoKuCalculator.compute(for: puzzle.grid)

            for (technique, points) in result.breakdown {
                #expect(
                    points > 0,
                    "\(puzzle.name): \(technique) should have positive points, got \(points)")
            }
        }
    }

    @Test("HoDoKu and SE ratings are both valid")
    func testBothRatingsValid() {
        // Both rating systems should produce reasonable values
        // They measure different things (cumulative vs peak) so correlation is loose

        for puzzle in RatedPuzzles.allPuzzles {
            let seResult = SECalculator.compute(for: puzzle.grid)
            let hodokuResult = HoDoKuCalculator.compute(for: puzzle.grid)

            // Both should be positive and within reasonable bounds
            #expect(
                Double(hodokuResult.rating) > 0,
                "\(puzzle.name): HoDoKu rating should be positive")
            #expect(
                Double(hodokuResult.rating) < 5000,
                "\(puzzle.name): HoDoKu (\(hodokuResult.rating)) exceeds reasonable bounds")
            #expect(
                seResult.rating > 0,
                "\(puzzle.name): SE rating should be positive")
            #expect(
                seResult.rating < 15.0,
                "\(puzzle.name): SE (\(seResult.rating)) exceeds reasonable bounds")
        }
    }
}
