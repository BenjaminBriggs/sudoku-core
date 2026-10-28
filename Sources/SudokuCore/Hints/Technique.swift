//
//  Technique.swift
//  SudokuCore
//
import Foundation

/// Stable identifier for a solving technique. Encodes as a bare string, matching
/// the legacy `HintTechnique` enum's raw-value encoding, so shipped puzzle JSON
/// keeps decoding. Raw values for classic techniques must never change.
///
/// `"yWing"` was a duplicate of XY-Wing and has merged into it, so it reads as
/// `"xyWing"`: puzzles and profiles saved with that name still find XY-Wing.
///
/// Ids are not validated and nothing prevents collisions — a technique minted
/// with a classic id (e.g. `"nakedSingle"`) silently shadows the built-in in
/// id-based lookups and rating maps. Namespace your own ids with a module
/// prefix, as the killer module does (`killer.cageLastCell`); bare camel-case
/// names are reserved for classic techniques.
public struct TechniqueID: RawRepresentable, Hashable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue == "yWing" ? "xyWing" : rawValue }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    public var description: String { rawValue }
}

extension TechniqueID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Identity, solve-order rank, and (optional) standard rating metadata for a technique.
/// Rating metadata is nil for variant techniques — the package does not rate variant puzzles.
public struct TechniqueInfo: Codable, Hashable, Sendable, Identifiable {
    public let id: TechniqueID
    /// Solve-order rank (lower = easier). Matches the legacy enum's difficulty scale.
    public let difficulty: Int
    /// Sudoku Explainer identifier, nil for unrated techniques.
    public let seId: String?
    /// Sudoku Explainer step difficulty, nil for unrated techniques.
    public let seStepValue: Double?
    /// HoDoKu identifier, nil for unrated techniques.
    public let hodokuId: String?
    /// Points each step with this technique adds to a puzzle's ``PuzzleDifficulty/score``,
    /// nil for unrated techniques. SudokuCore's own scale, tuned together with
    /// ``PuzzleDifficulty/Level/scoreRange``; not HoDoKu's step scores.
    public let scorePoints: Double?

    public init(
        id: TechniqueID,
        difficulty: Int,
        seId: String? = nil,
        seStepValue: Double? = nil,
        hodokuId: String? = nil,
        scorePoints: Double? = nil
    ) {
        self.id = id
        self.difficulty = difficulty
        self.seId = seId
        self.seStepValue = seStepValue
        self.hodokuId = hodokuId
        self.scorePoints = scorePoints
    }
}

extension TechniqueInfo {
    /// Classic constant builder keeping seId == hodokuId, as the legacy enum did.
    private static func classic(
        _ id: TechniqueID, _ difficulty: Int, _ seId: String,
        _ seStepValue: Double, _ scorePoints: Double
    ) -> TechniqueInfo {
        TechniqueInfo(
            id: id, difficulty: difficulty, seId: seId,
            seStepValue: seStepValue, hodokuId: seId, scorePoints: scorePoints)
    }

    public static let validation = classic("validation", 0, "Validation", 0.0, 0)
    public static let nakedSingle = classic("nakedSingle", 10, "Single", 1.2, 10)
    public static let hiddenSingle = classic("hiddenSingle", 20, "Hidden Single", 1.5, 12)
    public static let lockedCandidatesPointing = classic(
        "lockedCandidatesPointing", 40, "Pointing", 2.6, 20)
    public static let lockedCandidatesClaiming = classic(
        "lockedCandidatesClaiming", 40, "Claiming", 2.6, 20)
    public static let nakedPair = classic("nakedPair", 50, "Naked Pair", 2.0, 20)
    public static let hiddenPair = classic("hiddenPair", 50, "Hidden Pair", 2.2, 24)
    public static let nakedTriple = classic("nakedTriple", 60, "Naked Triple", 2.6, 30)
    public static let hiddenTriple = classic("hiddenTriple", 60, "Hidden Triple", 2.8, 36)
    public static let nakedQuad = classic("nakedQuad", 70, "Naked Quad", 3.2, 40)
    public static let hiddenQuad = classic("hiddenQuad", 70, "Hidden Quad", 3.4, 48)
    public static let xWing = classic("xWing", 80, "X-Wing", 3.8, 60)
    public static let finnedXWing = classic("finnedXWing", 85, "Finned X-Wing", 4.2, 70)
    public static let swordfish = classic("swordfish", 90, "Swordfish", 4.4, 90)
    public static let skyscraper = classic("skyscraper", 90, "Skyscraper", 4.0, 80)
    public static let twoStringKite = classic("twoStringKite", 90, "Two-String Kite", 4.0, 80)
    public static let emptyRectangle = classic("emptyRectangle", 92, "Empty Rectangle", 4.0, 80)
    public static let finnedSwordfish = classic(
        "finnedSwordfish", 95, "Finned Swordfish", 4.8, 100)
    public static let wWing = classic("wWing", 95, "W-Wing", 4.4, 90)
    public static let jellyfish = classic("jellyfish", 100, "Jellyfish", 4.8, 120)
    public static let finnedJellyfish = classic(
        "finnedJellyfish", 105, "Finned Jellyfish", 5.1, 130)
    public static let xyWing = classic("xyWing", 110, "XY-Wing", 4.5, 110)
    public static let xyzWing = classic("xyzWing", 120, "XYZ-Wing", 5.2, 130)
    public static let crane = classic("crane", 91, "Crane", 4.0, 80)
    public static let uniqueRectangleType1 = classic(
        "uniqueRectangleType1", 96, "Unique Rectangle Type 1", 4.5, 100)
    public static let uniqueRectangleType2 = classic(
        "uniqueRectangleType2", 97, "Unique Rectangle Type 2", 4.5, 100)
    public static let uniqueRectangleType3 = classic(
        "uniqueRectangleType3", 101, "Unique Rectangle Type 3", 4.6, 100)
    public static let uniqueRectangleType4 = classic(
        "uniqueRectangleType4", 98, "Unique Rectangle Type 4", 4.5, 100)
    public static let uniqueRectangleType5 = classic(
        "uniqueRectangleType5", 99, "Unique Rectangle Type 5", 4.6, 100)
    public static let bug = classic("bug", 115, "BUG+1", 5.6, 100)
    public static let fourYWing = classic("fourYWing", 125, "4-Y-Wing", 5.4, 140)
    public static let fiveYWing = classic("fiveYWing", 130, "5-Y-Wing", 5.6, 160)
    public static let sixYWing = classic("sixYWing", 135, "6-Y-Wing", 5.8, 180)
    public static let sevenYWing = classic("sevenYWing", 140, "7-Y-Wing", 6.0, 200)
    public static let unknown = classic("unknown", 9999, "Unknown", 8.0, 200)

    /// All classic technique infos, one per legacy enum case (35 total), in the exact
    /// order the legacy `orderedCases` produced: stable sort by difficulty over enum
    /// declaration order. Ties resolve by declaration order — that is why swordfish
    /// (difficulty 90, declared before skyscraper/twoStringKite) precedes them and
    /// finnedSwordfish precedes wWing (95).
    public static let allClassic: [TechniqueInfo] = [
        .validation, .nakedSingle, .hiddenSingle,
        .lockedCandidatesPointing, .lockedCandidatesClaiming,
        .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad,
        .xWing, .finnedXWing,
        .swordfish, .skyscraper, .twoStringKite, .crane, .emptyRectangle,
        .finnedSwordfish, .wWing,
        .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4,
        .uniqueRectangleType5, .jellyfish, .uniqueRectangleType3, .finnedJellyfish,
        .xyWing, .bug, .xyzWing,
        .fourYWing, .fiveYWing, .sixYWing, .sevenYWing, .unknown,
    ]
}

/// A solving technique: identity plus the ability to find a hint in a board state.
/// Conform to this to add techniques — classic (third-party apps) or variant (e.g. killer).
public protocol HintTechnique: Sendable {
    var info: TechniqueInfo { get }
    func findHint(in state: BoardState) -> HintStep?
}
