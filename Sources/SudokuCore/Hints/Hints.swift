//
//  Hints.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation

public enum HintTechnique: String, CaseIterable, Sendable, Codable, Identifiable {

    public var id: String { rawValue }

    public static var orderedCases: [HintTechnique] {
        allCases.sorted { $0.difficulty < $1.difficulty }
    }

    case unknown
    case validation
    case nakedSingle
    case hiddenSingle
    case lockedCandidatesPointing
    case lockedCandidatesClaiming
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case swordfish
    case jellyfish
    case finnedXWing
    case finnedSwordfish
    case finnedJellyfish
    case skyscraper
    case twoStringKite
    case emptyRectangle
    case xyWing
    case xyzWing
    case yWing
    case wWing

    /// An approximate difficulty scale (1 = easiest, higher = more complex).
    /// Adjust these as you see fit for your puzzle’s difficulty progression.
    public var difficulty: Int {
        switch self {
        case .validation:
            return 0
        case .nakedSingle:
            return 10
        case .hiddenSingle:
            return 20
        case .lockedCandidatesPointing, .lockedCandidatesClaiming:
            return 40
        case .nakedPair, .hiddenPair:
            return 50
        case .nakedTriple, .hiddenTriple:
            return 60
        case .nakedQuad, .hiddenQuad:
            return 70
        case .xWing:
            return 80
        case .finnedXWing:
            return 85
        case .skyscraper, .twoStringKite:
            return 90
        case .swordfish:
            return 90
        case .emptyRectangle:
            return 92
        case .finnedSwordfish:
            return 95
        case .wWing:
            return 95
        case .jellyfish:
            return 100
        case .finnedJellyfish:
            return 105
        case .xyWing, .yWing:
            return 110
        case .xyzWing:
            return 120
        case .unknown:
            return 9999
        }
    }

    // MARK: - Standard Rating Metadata

    /// Display/name used in SE mapping for this technique
    public var seId: String {
        switch self {
        case .nakedSingle: return "Single"
        case .hiddenSingle: return "Hidden Single"
        case .lockedCandidatesPointing: return "Pointing"
        case .lockedCandidatesClaiming: return "Claiming"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .hiddenTriple: return "Hidden Triple"
        case .nakedQuad: return "Naked Quad"
        case .hiddenQuad: return "Hidden Quad"
        case .xWing: return "X-Wing"
        case .finnedXWing: return "Finned X-Wing"
        case .swordfish: return "Swordfish"
        case .finnedSwordfish: return "Finned Swordfish"
        case .jellyfish: return "Jellyfish"
        case .finnedJellyfish: return "Finned Jellyfish"
        case .xyWing: return "XY-Wing"
        case .yWing: return "Y-Wing"
        case .xyzWing: return "XYZ-Wing"
        case .skyscraper: return "Skyscraper"
        case .twoStringKite: return "Two-String Kite"
        case .emptyRectangle: return "Empty Rectangle"
        case .wWing: return "W-Wing"
        case .validation: return "Validation"
        case .unknown: return "Unknown"
        }
    }

    /// SE step difficulty (approximate; calibrate with benchmarks)
    public var seStepValue: Double {
        switch self {
        case .validation: return 0.0
        case .nakedSingle: return 1.2
        case .hiddenSingle: return 1.5
        case .lockedCandidatesPointing, .lockedCandidatesClaiming: return 2.6
        case .nakedPair: return 2.0
        case .hiddenPair: return 2.2
        case .nakedTriple: return 2.6
        case .hiddenTriple: return 2.8
        case .nakedQuad: return 3.2
        case .hiddenQuad: return 3.4
        case .xWing: return 3.8
        case .finnedXWing: return 4.2
        case .swordfish: return 4.4
        case .finnedSwordfish: return 4.8
        case .jellyfish: return 4.8
        case .finnedJellyfish: return 5.1
        case .yWing: return 4.3
        case .xyWing: return 4.5
        case .xyzWing: return 5.2
        case .skyscraper: return 4.0
        case .twoStringKite: return 4.0
        case .emptyRectangle: return 4.0
        case .wWing: return 4.4
        case .unknown: return 8.0
        }
    }

    /// Display/name used in HoDoKu mapping for this technique
    public var hodokuId: String { seId }

    /// HoDoKu base points (cumulative effort; calibrate with HoDoKu docs)
    public var hodokuPoints: Double {
        switch self {
        case .validation: return 0
        case .nakedSingle: return 10
        case .hiddenSingle: return 12
        case .lockedCandidatesPointing, .lockedCandidatesClaiming: return 20
        case .nakedPair: return 20
        case .hiddenPair: return 24
        case .nakedTriple: return 30
        case .hiddenTriple: return 36
        case .nakedQuad: return 40
        case .hiddenQuad: return 48
        case .xWing: return 60
        case .finnedXWing: return 70
        case .swordfish: return 90
        case .finnedSwordfish: return 100
        case .jellyfish: return 120
        case .finnedJellyfish: return 130
        case .yWing: return 100
        case .xyWing: return 110
        case .xyzWing: return 130
        case .skyscraper: return 80
        case .twoStringKite: return 80
        case .emptyRectangle: return 80
        case .wWing: return 90
        case .unknown: return 200
        }
    }
}

public struct HintAction: Sendable {
    public enum ActionType: Sendable {
        case solveAs(Int)
        case ruleOut(Int)
        case pencilIn(Int)
        case clear
    }
    public let position: Puzzle.Index
    public let action: ActionType
    public init(
        position: Puzzle.Index,
        solveAs: Int
    ) {
        self.position = position
        self.action = .solveAs(solveAs)
    }

    public init(
        position: Puzzle.Index,
        ruleOut: Int
    ) {
        self.position = position
        self.action = .ruleOut(ruleOut)
    }

    public init(
        position: Puzzle.Index,
        pencilIn: Int
    ) {
        self.position = position
        self.action = .pencilIn(pencilIn)
    }

    public init(
        clearPosition position: Puzzle.Index
    ) {
        self.position = position
        self.action = .clear
    }

    public var debugDescription: String {
        switch action {
        case .solveAs(let solveAs):
            return "Hint add \(solveAs) at \(position.description)"
        case .ruleOut(let ruleOut):
            return "Hint remove \(ruleOut) at \(position.description)"
        case .pencilIn(let pencilIn):
            return "Hint pencil \(pencilIn) at \(position.description)"
        case .clear:
            return "Hint clear at \(position.description)"
        }
    }
}

/// Example struct for a single deduction hint.
public struct HintStep: CustomDebugStringConvertible, Sendable {
    public let actions: [HintAction]

    /// The technique used for this deduction.
    public let technique: HintTechnique

    /// Structured, machine-readable record of how this hint was determined.
    ///
    /// Captures the logical premises of the deduction so the app can validate, re-present,
    /// or generatively explain the hint. Presentation (the human-facing explanation) is built
    /// from this, outside core.
    public let reasoning: HintReasoning

    public var debugDescription: String {
        "Hint(\(technique.rawValue), \(actions))"
    }

    public init(
        actions: [HintAction],
        technique: HintTechnique,
        reasoning: HintReasoning = HintReasoning()
    ) {
        self.actions = actions
        self.technique = technique
        self.reasoning = reasoning
    }
}
