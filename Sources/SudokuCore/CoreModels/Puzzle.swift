//
//  Puzzle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//
import Foundation

public struct Puzzle: Codable, Hashable, Identifiable, Sendable {
    /// Identity of the puzzle's content. Unless an id is given, it is derived by
    /// ``derivedID(startingState:constraints:)``: the 81-digit starting state, and
    /// for a puzzle with constraints a `~` followed by each constraint's
    /// ``Constraint/identity``, sorted and joined by `_`. Solution and presentation
    /// never take part. Decoding keeps whatever id the JSON carries.
    public let id: String
    public let solution: [[Int]]
    public let startingState: [[Int]]
    public let difficulty: PuzzleDifficulty
    /// Additive variant rules (e.g. killer cages). Empty for classic puzzles.
    public let constraints: [AnyConstraint]
    /// Opaque presentation payload (overlay SVG, rules text) the app renders.
    public let presentation: PuzzlePresentation?

    /// - Parameter id: An authored id, for bespoke puzzles whose rules live only in
    ///   `presentation` and so cannot be told apart by their givens and constraints.
    ///   Pass `nil` to derive the id from the content.
    public init(
        id: String? = nil,
        solution: [[Int]],
        startingState: [[Int]],
        difficulty: PuzzleDifficulty,
        constraints: [AnyConstraint] = [],
        presentation: PuzzlePresentation? = nil
    ) {
        self.id = id ?? Self.derivedID(startingState: startingState, constraints: constraints)
        self.solution = solution
        self.startingState = startingState
        self.difficulty = difficulty
        self.constraints = constraints
        self.presentation = presentation
    }

    /// The id a puzzle gets when none is authored: the starting state's 81 digits,
    /// plus `~` and the sorted constraint identities joined by `_` when there are
    /// constraints. Classic puzzles keep the id they have always had.
    public static func derivedID(startingState: [[Int]], constraints: [AnyConstraint]) -> String {
        var id = startingState.flatString(empty: "0")
        if constraints.isEmpty == false {
            id += "~" + constraints.map(\.identity).sorted().joined(separator: "_")
        }
        return id
    }

    private enum CodingKeys: String, CodingKey {
        case id, solution, startingState, difficulty, constraints, presentation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.solution = try container.decode([[Int]].self, forKey: .solution)
        self.startingState = try container.decode([[Int]].self, forKey: .startingState)
        self.difficulty = try container.decode(PuzzleDifficulty.self, forKey: .difficulty)
        self.constraints =
            try container.decodeIfPresent([AnyConstraint].self, forKey: .constraints) ?? []
        self.presentation =
            try container.decodeIfPresent(PuzzlePresentation.self, forKey: .presentation)
    }

    /// Classic puzzles encode exactly as they did before constraints existed: the
    /// `constraints` key appears only when there are constraints, and
    /// `presentation` only when set.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(solution, forKey: .solution)
        try container.encode(startingState, forKey: .startingState)
        try container.encode(difficulty, forKey: .difficulty)
        if constraints.isEmpty == false {
            try container.encode(constraints, forKey: .constraints)
        }
        try container.encodeIfPresent(presentation, forKey: .presentation)
    }
}

/// Presentation payload for bespoke puzzles. Opaque to core; the app renders it.
public struct PuzzlePresentation: Codable, Hashable, Sendable {
    /// SVG drawn over the grid (cage outlines, decorations). Coordinate system is app-defined.
    public let overlaySVG: String?
    /// Human-readable rules, as authored. Core never interprets this.
    public let rulesText: String?

    public init(overlaySVG: String? = nil, rulesText: String? = nil) {
        self.overlaySVG = overlaySVG
        self.rulesText = rulesText
    }
}

/// Represents the intrinsic difficulty of a Sudoku puzzle
///
/// # Score
/// The `score` field is SudokuCore's cumulative effort score: the sum of
/// ``TechniqueInfo/scorePoints`` over each step of the solve (see ``ScoreCalculator``).
/// ``Level/scoreRange`` gives each level's range.
///
/// ## Additional Ratings
/// - **seRating**: Sudoku Explainer rating (difficulty of hardest technique)
/// - **hodokuRating** and **hodokuLevel**: ``HoDoKuCalculator``'s estimate of HoDoKu's own
///   score and level. Puzzles rated before SudokuCore 2.0 hold their `score` in `hodokuRating`
///   and have no `hodokuLevel`.
/// - **estimatedTimeSeconds**: Predicted completion time
///
/// This base rating is separate from performance scoring, which evaluates how well
/// a player completed the puzzle (time, hints used, errors made).
public struct PuzzleDifficulty: Sendable, Codable, Hashable {
    /// Difficulty category (easy, medium, hard, expert, professional, custom)
    public let level: Level

    /// Most advanced technique required to solve the puzzle
    public let hardestTechnique: TechniqueID

    /// Cumulative effort score: the sum of each solve step's ``TechniqueInfo/scorePoints``,
    /// on SudokuCore's own scale rather than HoDoKu's.
    /// Represents intrinsic puzzle difficulty independent of player performance
    public let score: Int

    /// Optional standard ratings and time estimate
    public let seRating: Double?
    public let hodokuRating: Int?
    public let hodokuLevel: HoDoKuLevel?
    public let estimatedTimeSeconds: Int?

    public init(
        level: Level,
        hardestTechnique: TechniqueID,
        score: Int,
        seRating: Double? = nil,
        hodokuRating: Int? = nil,
        hodokuLevel: HoDoKuLevel? = nil,
        estimatedTimeSeconds: Int? = nil
    ) {
        self.level = level
        self.hardestTechnique = hardestTechnique
        self.score = score
        self.seRating = seRating
        self.hodokuRating = hodokuRating
        self.hodokuLevel = hodokuLevel
        self.estimatedTimeSeconds = estimatedTimeSeconds
    }

    public enum Level: String, Codable, Hashable, CaseIterable, Sendable {
        case easy
        case medium
        case hard
        case expert
        case professional
        case custom
    }
}

extension Puzzle {
    public static func example() -> Puzzle {
        .init(
            solution: [
                [8, 2, 9, 1, 3, 5, 7, 4, 6],
                [1, 3, 4, 8, 6, 7, 2, 5, 9],
                [6, 7, 5, 4, 2, 9, 1, 3, 8],

                [3, 8, 1, 2, 7, 4, 9, 6, 5],
                [7, 5, 6, 3, 9, 8, 4, 2, 1],
                [9, 4, 2, 6, 5, 1, 3, 8, 7],

                [5, 9, 8, 7, 4, 3, 6, 1, 2],
                [4, 6, 7, 5, 1, 2, 8, 9, 3],
                [2, 1, 3, 9, 8, 6, 5, 7, 4],
            ],
            startingState: [
                [8, 0, 0, 0, 0, 5, 0, 4, 0],
                [1, 0, 0, 0, 0, 7, 2, 0, 9],
                [6, 0, 0, 0, 2, 0, 0, 3, 0],

                [0, 0, 0, 0, 0, 4, 9, 6, 5],
                [7, 5, 0, 3, 9, 0, 0, 2, 1],
                [9, 0, 0, 6, 5, 0, 0, 0, 7],

                [5, 9, 0, 7, 0, 3, 6, 1, 0],
                [4, 0, 0, 0, 0, 0, 8, 0, 0],
                [2, 0, 3, 9, 8, 0, 0, 0, 0],
            ],
            difficulty: PuzzleDifficulty(
                level: .easy,
                hardestTechnique: TechniqueInfo.hiddenSingle.id,
                score: 0
            )
        )
    }
}
