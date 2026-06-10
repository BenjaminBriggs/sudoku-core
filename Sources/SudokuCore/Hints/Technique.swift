//
//  Technique.swift
//  SudokuCore
//
import Foundation

/// Stable identifier for a solving technique. Encodes as a bare string, matching
/// the legacy `HintTechnique` enum's raw-value encoding, so shipped puzzle JSON
/// keeps decoding. Raw values for classic techniques must never change.
public struct TechniqueID: RawRepresentable, Hashable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
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
    /// HoDoKu base points, nil for unrated techniques.
    public let hodokuPoints: Double?

    public init(
        id: TechniqueID,
        difficulty: Int,
        seId: String? = nil,
        seStepValue: Double? = nil,
        hodokuId: String? = nil,
        hodokuPoints: Double? = nil
    ) {
        self.id = id
        self.difficulty = difficulty
        self.seId = seId
        self.seStepValue = seStepValue
        self.hodokuId = hodokuId
        self.hodokuPoints = hodokuPoints
    }
}

extension TechniqueInfo {
    /// Classic constant builder keeping seId == hodokuId, as the legacy enum did.
    private static func classic(
        _ id: TechniqueID, _ difficulty: Int, _ seId: String,
        _ seStepValue: Double, _ hodokuPoints: Double
    ) -> TechniqueInfo {
        TechniqueInfo(
            id: id, difficulty: difficulty, seId: seId,
            seStepValue: seStepValue, hodokuId: seId, hodokuPoints: hodokuPoints)
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
    public static let yWing = classic("yWing", 110, "Y-Wing", 4.3, 100)
    public static let xyzWing = classic("xyzWing", 120, "XYZ-Wing", 5.2, 130)
    public static let unknown = classic("unknown", 9999, "Unknown", 8.0, 200)

    /// All classic technique infos, one per legacy enum case (25 total), in the exact
    /// order the legacy `orderedCases` produced: stable sort by difficulty over enum
    /// declaration order. Ties resolve by declaration order — that is why swordfish
    /// (difficulty 90, declared before skyscraper/twoStringKite) precedes them,
    /// finnedSwordfish precedes wWing (95), and xyWing precedes yWing (110).
    public static let allClassic: [TechniqueInfo] = [
        .validation, .nakedSingle, .hiddenSingle,
        .lockedCandidatesPointing, .lockedCandidatesClaiming,
        .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad,
        .xWing, .finnedXWing,
        .swordfish, .skyscraper, .twoStringKite, .emptyRectangle,
        .finnedSwordfish, .wWing, .jellyfish, .finnedJellyfish,
        .xyWing, .yWing, .xyzWing, .unknown,
    ]
}

/// A solving technique: identity plus the ability to find a hint in a board state.
/// Conform to this to add techniques — classic (third-party apps) or variant (e.g. killer).
public protocol HintTechnique: Sendable {
    var info: TechniqueInfo { get }
    func findHint(in state: BoardState) -> HintStep?
}
