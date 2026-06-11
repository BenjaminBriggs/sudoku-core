import Testing

@testable import SudokuCore

@Suite("SECalculator")
struct SECalculatorTests {
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

    @Test("Uses enum values and picks max step (naked single → Single)")
    func seUsesEnumAndMax() {
        var grid = solved
        grid[8][8] = 0  // one naked single

        let result = SECalculator.compute(for: grid)
        #expect(result.rating == (TechniqueInfo.nakedSingle.seStepValue ?? 0))
        #expect(result.hardestTechniqueName == "Single")
        #expect(result.maxStepIndex == 0)
        #expect(result.pathSummary["Single"] == 1)
    }

    // MARK: - Comprehensive Rating Tests

    @Test("Very Easy puzzle (Naked Singles only) - SE ~1.2")
    func testVeryEasyRating() {
        let puzzle = RatedPuzzles.veryEasy
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Easy puzzle (Hidden Singles) - SE ~1.5")
    func testEasyRating() {
        let puzzle = RatedPuzzles.easy
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Medium puzzle (Pointing/Claiming) - SE ~2.6")
    func testMediumRating() {
        let puzzle = RatedPuzzles.medium
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Medium-Hard puzzle (Naked Pairs) - SE ~3.0")
    func testMediumHardRating() {
        let puzzle = RatedPuzzles.mediumHard
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Hard puzzle (X-Wing) - SE ~3.8")
    func testHardXWingRating() {
        let puzzle = RatedPuzzles.hardXWing
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Hard puzzle (Swordfish) - SE ~4.4")
    func testHardSwordfishRating() {
        let puzzle = RatedPuzzles.hardSwordfish
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Hard puzzle (XY-Wing) - SE ~4.5")
    func testHardXYWingRating() {
        let puzzle = RatedPuzzles.hardXYWing
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Very Hard puzzle (XYZ-Wing) - SE ~5.2")
    func testVeryHardXYZWingRating() {
        let puzzle = RatedPuzzles.veryHardXYZWing
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")
        #expect(
            result.hardestTechniqueName == puzzle.hardestTechnique,
            "Expected \(puzzle.hardestTechnique), got \(result.hardestTechniqueName)")
    }

    @Test("Naked Quad regression puzzle")
    func testNakedQuadRegression() {
        let puzzle = RatedPuzzles.nakedQuadRegression
        let result = SECalculator.compute(for: puzzle.grid)

        #expect(
            result.rating >= puzzle.expectedSE - puzzle.seRatingTolerance,
            "Rating \(result.rating) too low for \(puzzle.name)")
        #expect(
            result.rating <= puzzle.expectedSE + puzzle.seRatingTolerance,
            "Rating \(result.rating) too high for \(puzzle.name)")

        // Verify this puzzle is solvable without Unknown fallback
        #expect(
            result.hardestTechniqueName != "Unknown",
            "Regression: puzzle should be solvable without fallback")
    }

    // MARK: - Rating Distribution Tests

    @Test("All test puzzles produce valid ratings")
    func testAllPuzzlesHaveValidRatings() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = SECalculator.compute(for: puzzle.grid)

            #expect(result.rating > 0, "\(puzzle.name) should have positive rating")
            #expect(
                result.rating < 15.0,
                "\(puzzle.name) rating \(result.rating) exceeds reasonable bounds")
            #expect(
                result.hardestTechniqueName.isEmpty == false,
                "\(puzzle.name) should have hardest technique name")
            #expect(result.maxStepIndex >= 0, "\(puzzle.name) should have valid step index")
        }
    }

    @Test("Rating increases with difficulty level")
    func testRatingMonotonicity() {
        let veryEasyResult = SECalculator.compute(for: RatedPuzzles.veryEasy.grid)
        let easyResult = SECalculator.compute(for: RatedPuzzles.easy.grid)
        let mediumResult = SECalculator.compute(for: RatedPuzzles.medium.grid)
        let hardResult = SECalculator.compute(for: RatedPuzzles.hardXWing.grid)

        #expect(
            veryEasyResult.rating <= easyResult.rating,
            "Very Easy (\(veryEasyResult.rating)) should be ≤ Easy (\(easyResult.rating))")
        #expect(
            easyResult.rating <= mediumResult.rating,
            "Easy (\(easyResult.rating)) should be ≤ Medium (\(mediumResult.rating))")
        #expect(
            mediumResult.rating <= hardResult.rating,
            "Medium (\(mediumResult.rating)) should be ≤ Hard (\(hardResult.rating))")
    }

    @Test("Path summary correctly counts techniques")
    func testPathSummaryAccuracy() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = SECalculator.compute(for: puzzle.grid)

            let totalTechniques = result.pathSummary.values.reduce(0, +)
            #expect(totalTechniques > 0, "\(puzzle.name) should use at least one technique")

            // Verify all counts are positive
            for (technique, count) in result.pathSummary {
                #expect(count > 0, "\(puzzle.name): \(technique) should have positive count")
            }
        }
    }

    @Test("Used techniques list matches hardest technique")
    func testUsedTechniquesConsistency() {
        for puzzle in RatedPuzzles.allPuzzles {
            let result = SECalculator.compute(for: puzzle.grid)

            #expect(
                result.usedTechniques.contains(result.hardestTechniqueName),
                "\(puzzle.name): hardest technique '\(result.hardestTechniqueName)' should be in used list"
            )
        }
    }
}
