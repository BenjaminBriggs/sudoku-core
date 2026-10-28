//
//  TechniqueTestSupport.swift
//  SudokuCoreTests
//
//  Legacy-shaped helpers so pre-refactor tests stay textually close to their
//  original form, keeping the equivalence gate easy to review.
//
import Foundation

@testable import SudokuCore

extension HintFinder {
    /// Find a hint using a single classic technique, identified by its info.
    /// Mirrors the legacy `findHint(for:in:)`; `.unknown` yields nil, as before.
    static func findHint(for technique: TechniqueInfo, in state: BoardState) -> HintStep? {
        ClassicTechniques.technique(for: technique.id)?.findHint(in: state)
    }
}

extension TechniqueInfo {
    /// Legacy-shaped accessor for test messages; the enum's rawValue is now the id.
    var rawValue: String { id.rawValue }
}
