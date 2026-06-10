//
//  ClassicTechniques.swift
//  SudokuCore
//
//  The built-in classic solving techniques as HintTechnique conformers.
//  Each struct delegates to the existing static finder on HintFinder.
//
import Foundation

public struct ValidationTechnique: HintTechnique {
    public let info: TechniqueInfo = .validation
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.checkValidity(in: state)
    }
}

public struct NakedSingleTechnique: HintTechnique {
    public let info: TechniqueInfo = .nakedSingle
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findNakedSingle(in: state)
    }
}

public struct HiddenSingleTechnique: HintTechnique {
    public let info: TechniqueInfo = .hiddenSingle
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findHiddenSingle(in: state)
    }
}

public struct LockedCandidatesTechnique: HintTechnique {
    public enum Kind: Sendable { case pointing, claiming }
    public let kind: Kind
    public var info: TechniqueInfo {
        kind == .pointing ? .lockedCandidatesPointing : .lockedCandidatesClaiming
    }
    public init(kind: Kind) { self.kind = kind }
    public func findHint(in state: BoardState) -> HintStep? {
        switch kind {
        case .pointing: return HintFinder.findLockedCandidatesPointing(in: state)
        case .claiming: return HintFinder.findLockedCandidatesClaiming(in: state)
        }
    }
}

public struct NakedSubsetTechnique: HintTechnique {
    public let size: Int
    public var info: TechniqueInfo {
        switch size {
        case 2: return .nakedPair
        case 3: return .nakedTriple
        default: return .nakedQuad
        }
    }
    public init(size: Int) {
        precondition((2...4).contains(size))
        self.size = size
    }
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findNakedSubsets(n: size, technique: info, in: state)
    }
}

public struct HiddenSubsetTechnique: HintTechnique {
    public let size: Int
    public var info: TechniqueInfo {
        switch size {
        case 2: return .hiddenPair
        case 3: return .hiddenTriple
        default: return .hiddenQuad
        }
    }
    public init(size: Int) {
        precondition((2...4).contains(size))
        self.size = size
    }
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findHiddenSubsets(n: size, technique: info, in: state)
    }
}

public struct FishTechnique: HintTechnique {
    public let size: Int
    public let finned: Bool
    public var info: TechniqueInfo {
        switch (size, finned) {
        case (2, false): return .xWing
        case (2, true): return .finnedXWing
        case (3, false): return .swordfish
        case (3, true): return .finnedSwordfish
        case (4, false): return .jellyfish
        default: return .finnedJellyfish
        }
    }
    public init(size: Int, finned: Bool) {
        precondition((2...4).contains(size))
        self.size = size
        self.finned = finned
    }
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findNFish(n: size, requiresFin: finned, in: state)
    }
}

public struct SkyscraperTechnique: HintTechnique {
    public let info: TechniqueInfo = .skyscraper
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findSkyscraper(in: state)
    }
}

public struct TwoStringKiteTechnique: HintTechnique {
    public let info: TechniqueInfo = .twoStringKite
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findTwoStringKite(in: state)
    }
}

public struct EmptyRectangleTechnique: HintTechnique {
    public let info: TechniqueInfo = .emptyRectangle
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findEmptyRectangle(in: state)
    }
}

public struct XYWingTechnique: HintTechnique {
    public let info: TechniqueInfo = .xyWing
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findXYWing(in: state)
    }
}

public struct XYZWingTechnique: HintTechnique {
    public let info: TechniqueInfo = .xyzWing
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findXYZWing(in: state)
    }
}

public struct YWingTechnique: HintTechnique {
    public let info: TechniqueInfo = .yWing
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findYWing(in: state)
    }
}

public struct WWingTechnique: HintTechnique {
    public let info: TechniqueInfo = .wWing
    public init() {}
    public func findHint(in state: BoardState) -> HintStep? {
        HintFinder.findWWing(in: state)
    }
}

/// The built-in classic technique set, in solve order (easiest first).
/// Replaces the legacy `HintTechnique.orderedCases`. Does not include an
/// "unknown" entry — the legacy `.unknown` case never produced hints.
public enum ClassicTechniques {
    public static let all: [any HintTechnique] = [
        ValidationTechnique(),
        NakedSingleTechnique(),
        HiddenSingleTechnique(),
        LockedCandidatesTechnique(kind: .pointing),
        LockedCandidatesTechnique(kind: .claiming),
        NakedSubsetTechnique(size: 2),
        HiddenSubsetTechnique(size: 2),
        NakedSubsetTechnique(size: 3),
        HiddenSubsetTechnique(size: 3),
        NakedSubsetTechnique(size: 4),
        HiddenSubsetTechnique(size: 4),
        FishTechnique(size: 2, finned: false),
        FishTechnique(size: 2, finned: true),
        FishTechnique(size: 3, finned: false),
        SkyscraperTechnique(),
        TwoStringKiteTechnique(),
        EmptyRectangleTechnique(),
        FishTechnique(size: 3, finned: true),
        WWingTechnique(),
        FishTechnique(size: 4, finned: false),
        FishTechnique(size: 4, finned: true),
        XYWingTechnique(),
        YWingTechnique(),
        XYZWingTechnique(),
    ]

    /// Look up a classic technique by id.
    public static func technique(for id: TechniqueID) -> (any HintTechnique)? {
        all.first { $0.info.id == id }
    }
}
