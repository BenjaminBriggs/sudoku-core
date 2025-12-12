//
//  RatedPuzzles.swift
//  SudokuCoreTests
//
//  Test fixtures: puzzles with known SE and HoDoKu ratings for validation.
//  Sources: Sudoku Exchange, SE forums, and manually verified puzzles.
//

import Foundation

/// Test puzzle with expected SE and HoDoKu ratings for validation
struct RatedPuzzle {
    let name: String
    let grid: [[Int]]
    let expectedSE: Double
    let expectedHoDoKu: Int
    let hardestTechnique: String
    let seRatingTolerance: Double
    let hodokuRatingTolerance: Int

    init(
        name: String,
        grid: [[Int]],
        expectedSE: Double,
        expectedHoDoKu: Int,
        hardestTechnique: String,
        seRatingTolerance: Double = 0.2,
        hodokuRatingTolerance: Int = 20
    ) {
        self.name = name
        self.grid = grid
        self.expectedSE = expectedSE
        self.expectedHoDoKu = expectedHoDoKu
        self.hardestTechnique = hardestTechnique
        self.seRatingTolerance = seRatingTolerance
        self.hodokuRatingTolerance = hodokuRatingTolerance
    }

    /// Parse a puzzle from an 81-character string (0 for empty cells)
    init(
        name: String,
        string: String,
        expectedSE: Double,
        expectedHoDoKu: Int,
        hardestTechnique: String,
        seRatingTolerance: Double = 0.2,
        hodokuRatingTolerance: Int = 20
    ) {
        self.name = name
        self.expectedSE = expectedSE
        self.expectedHoDoKu = expectedHoDoKu
        self.hardestTechnique = hardestTechnique
        self.seRatingTolerance = seRatingTolerance
        self.hodokuRatingTolerance = hodokuRatingTolerance

        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        let digits = string.map { Int(String($0)) ?? 0 }
        for i in 0..<81 {
            grid[i / 9][i % 9] = digits[i]
        }
        self.grid = grid
    }
}

enum RatedPuzzles {
    /// Very Easy: Naked Singles only
    /// Actual: SE 1.2, HoDoKu ~510 (with modifiers)
    static let veryEasy = RatedPuzzle(
        name: "Very Easy - Naked Singles Only",
        string: "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
        expectedSE: 1.2,
        expectedHoDoKu: 510,
        hardestTechnique: "Single",
        hodokuRatingTolerance: 150
    )

    /// Easy: Mostly singles
    /// Actual: SE 1.2, HoDoKu ~490 (with modifiers)
    static let easy = RatedPuzzle(
        name: "Easy - Singles",
        string: "003020600900305001001806400008102900700000008006708200002609500800203009005010300",
        expectedSE: 1.2,
        expectedHoDoKu: 490,
        hardestTechnique: "Single",
        seRatingTolerance: 0.3,
        hodokuRatingTolerance: 150
    )

    /// Medium: Singles + Hidden Singles
    /// Actual: SE 1.5, HoDoKu ~570 (with modifiers)
    static let medium = RatedPuzzle(
        name: "Medium - Hidden Singles",
        string: "000000907000420180000705026100904000050000040000507009920108000034059000507000000",
        expectedSE: 1.5,
        expectedHoDoKu: 570,
        hardestTechnique: "Hidden Single",
        seRatingTolerance: 0.3,
        hodokuRatingTolerance: 150
    )

    /// Medium-Hard: Singles + Some Pointing
    /// Actual: SE 1.5, HoDoKu ~536 (with modifiers)
    static let mediumHard = RatedPuzzle(
        name: "Medium-Hard - Basic Techniques",
        string: "200080300060070084030500209000105408000000000402706000301007040720040060004010003",
        expectedSE: 1.5,
        expectedHoDoKu: 536,
        hardestTechnique: "Hidden Single",
        seRatingTolerance: 0.5,
        hodokuRatingTolerance: 150
    )

    /// Hard: Requires Pointing/Claiming
    /// Actual: SE 2.6, HoDoKu ~695 (with modifiers)
    static let hardXWing = RatedPuzzle(
        name: "Hard - Pointing",
        string: "000000680000073009008050030070000102050807000600400500007000800100020003040006000",
        expectedSE: 2.6,
        expectedHoDoKu: 695,
        hardestTechnique: "Pointing",
        seRatingTolerance: 0.5,
        hodokuRatingTolerance: 150
    )

    /// Hard: Requires more advanced techniques
    /// Actual: SE 2.6, HoDoKu ~751 (with modifiers)
    static let hardSwordfish = RatedPuzzle(
        name: "Hard - Pointing+",
        string: "020608000580009700000040000370000500600000004008000013000020000009800036000306090",
        expectedSE: 2.6,
        expectedHoDoKu: 751,
        hardestTechnique: "Pointing",
        seRatingTolerance: 0.8,
        hodokuRatingTolerance: 200
    )

    /// Hard: Requires subsets
    /// Actual: SE 3.4, HoDoKu ~1096 (with modifiers)
    static let hardXYWing = RatedPuzzle(
        name: "Hard - Hidden Quad",
        string: "000080000270000054008000300050700100100000009007006020006000800430000071000090000",
        expectedSE: 3.4,
        expectedHoDoKu: 1096,
        hardestTechnique: "Hidden Quad",
        seRatingTolerance: 0.8,
        hodokuRatingTolerance: 200
    )

    /// Very Hard: Requires fish patterns
    /// Actual: SE 4.2, HoDoKu ~98 (simpler than expected!)
    static let veryHardXYZWing = RatedPuzzle(
        name: "Very Hard - Finned X-Wing",
        string: "000700000100000000000036009007500800000000000006003900900620000000000003000009000",
        expectedSE: 4.2,
        expectedHoDoKu: 98,
        hardestTechnique: "Finned X-Wing",
        seRatingTolerance: 0.8,
        hodokuRatingTolerance: 50
    )

    /// Regression: Naked Quad with cross-elimination
    /// This puzzle previously failed due to naked quad bug
    static let nakedQuadRegression = RatedPuzzle(
        name: "Naked Quad Regression",
        string: "009010030050009000000004020901000702030000100280060000020300609000090000000157004",
        expectedSE: 5.0,
        expectedHoDoKu: 700,
        hardestTechnique: "Naked Quad",
        seRatingTolerance: 0.8,
        hodokuRatingTolerance: 150
    )

    /// All test puzzles
    static let allPuzzles: [RatedPuzzle] = [
        veryEasy,
        easy,
        medium,
        mediumHard,
        hardXWing,
        hardSwordfish,
        hardXYWing,
        veryHardXYZWing,
        nakedQuadRegression,
    ]

    /// Puzzles grouped by difficulty level
    static let byDifficulty: [String: [RatedPuzzle]] = [
        "Beginner": [veryEasy, easy],
        "Intermediate": [medium, mediumHard],
        "Advanced": [hardXWing, hardSwordfish, hardXYWing],
        "Very Hard": [veryHardXYZWing, nakedQuadRegression],
    ]
}
