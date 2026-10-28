import Testing

@testable import SudokuCore

@Suite("HoDoKuCalculator")
struct HoDoKuCalculatorTests {
    @Test("Every classic technique has a HoDoKu step")
    func everyTechniqueHasAStep() {
        for technique in ClassicTechniques.all where technique.info != .validation {
            #expect(RatingTables.HoDoKu.steps[technique.info.id] != nil, "\(technique.info.id)")
        }
    }

    @Test("Techniques run in HoDoKu's order")
    func hodokuOrder() {
        let ids = HoDoKuCalculator.techniques.map(\.info)
        #expect(ids.count == ClassicTechniques.all.count)
        #expect(ids.first == .validation)
        let orders = ids.dropFirst().map { RatingTables.HoDoKu.steps[$0.id]!.order }
        #expect(orders == orders.sorted())
        // Unlike the hint finder, HoDoKu tries finned fish after the wings and uniqueness tests.
        #expect(ids.firstIndex(of: .finnedXWing)! > ids.firstIndex(of: .uniqueRectangleType5)!)
        #expect(ids.firstIndex(of: .nakedTriple)! < ids.firstIndex(of: .hiddenPair)!)
    }

    @Test("A single scores HoDoKu's 4 points and is easy")
    func singleStep() throws {
        var grid = Puzzle.example().solution
        grid[8][8] = 0
        let rating = try #require(HoDoKuCalculator.compute(for: grid))
        #expect(rating.score == 4)
        #expect(rating.level == .easy)
        #expect(rating.breakdown == [TechniqueInfo.nakedSingle.id: 4])
    }

    @Test("No rating when the hint finder can't solve the puzzle")
    func unsolvable() {
        #expect(HoDoKuCalculator.compute(for: Solution.empty()) == nil)
    }

    /// Every tenth recorded puzzle, 15 across HoDoKu's levels.
    static let puzzles = HoDoKuRatingFixture.recorded.enumerated().filter { $0.offset % 10 == 0 }.map(\.element)

    @Test("The level is the higher of the score's and the hardest step's")
    func level() throws {
        try #require(Self.puzzles.isEmpty == false)
        for puzzle in Self.puzzles {
            let rating = try #require(HoDoKuCalculator.compute(for: puzzle.rows), "\(puzzle.grid)")
            let byScore = HoDoKuLevel.allCases.first { rating.score <= $0.maxScore }!
            let byStep = rating.breakdown.keys.map { RatingTables.HoDoKu.steps[$0]!.level }.max()!
            #expect(rating.level == max(byScore, byStep), "\(puzzle.grid)")
            #expect(rating.breakdown.values.reduce(0, +) == rating.score, "\(puzzle.grid)")
        }
    }

    @Test("The difficulty calculator reports the estimate")
    func calculatorReportsIt() throws {
        let grid = try #require(HoDoKuRatingFixture.recorded.first { $0.level == .hard }).rows
        let rating = HoDoKuCalculator.compute(for: grid)
        let result = try SudokuDifficultyCalculator.calculateDifficulty(for: grid)
        #expect(result.hodokuRating == rating?.score)
        #expect(result.hodokuLevel == rating?.level)
        #expect(result.puzzleDifficulty.hodokuLevel == rating?.level)
    }

    @Test("HoDoKu's levels and cut-offs")
    func levels() {
        #expect(HoDoKuLevel.allCases.map(\.maxScore) == [800, 1000, 1600, 1800, .max])
        #expect(HoDoKuLevel.easy < .medium && .unfair < .extreme)
    }
}
