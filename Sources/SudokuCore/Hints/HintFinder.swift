//
//  HintFinder.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

public enum HintFinder {
    public static func findHint(for technique: HintTechnique, in state: BoardState) -> HintStep? {
        switch technique {
        case .validation:
            return checkValidity(in: state)
        case .nakedSingle:
            return findNakedSingle(in: state)
        case .hiddenSingle:
            return findHiddenSingle(in: state)
        case .lockedCandidatesPointing:
            return findLockedCandidatesPointing(in: state)
        case .lockedCandidatesClaiming:
            return findLockedCandidatesClaiming(in: state)
        case .nakedPair:
            return findNakedSubsets(n: 2, technique: .nakedPair, in: state)
        case .hiddenPair:
            return findHiddenSubsets(n: 2, technique: .hiddenPair, in: state)
        case .nakedTriple:
            return findNakedSubsets(n: 3, technique: .nakedTriple, in: state)
        case .hiddenTriple:
            return findHiddenSubsets(n: 3, technique: .hiddenTriple, in: state)
        case .nakedQuad:
            return findNakedSubsets(n: 4, technique: .nakedQuad, in: state)
        case .hiddenQuad:
            return findHiddenSubsets(n: 4, technique: .hiddenQuad, in: state)
        case .xyWing:
            return findXYWing(in: state)
        case .xyzWing:
            return findXYZWing(in: state)
        case .yWing:
            return findYWing(in: state)
        case .xWing:
            return findNFish(n: 2, requiresFin: false, in: state)
        case .finnedXWing:
            return findNFish(n: 2, requiresFin: true, in: state)
        case .swordfish:
            return findNFish(n: 3, requiresFin: false, in: state)
        case .finnedSwordfish:
            return findNFish(n: 3, requiresFin: true, in: state)
        case .jellyfish:
            return findNFish(n: 4, requiresFin: false, in: state)
        case .finnedJellyfish:
            return findNFish(n: 4, requiresFin: true, in: state)
        case .skyscraper:
            return findSkyscraper(in: state)
        case .unknown:
            return nil // this will never have a hint
        }
    }
}
