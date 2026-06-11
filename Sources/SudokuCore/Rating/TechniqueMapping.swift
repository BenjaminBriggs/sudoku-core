//
//  TechniqueMapping.swift
//  SudokuCore
//
//  Maps internal HintTechnique to external standard identifiers.
//

import Foundation

public enum TechniqueMapping {
    /// Return a stable identifier for SE tables for a given technique.
    /// Falls back to the technique id for unrated (variant) techniques.
    public static func seId(for technique: TechniqueInfo) -> String {
        technique.seId ?? technique.id.rawValue
    }

    /// Return a stable identifier for HoDoKu tables for a given technique.
    public static func hodokuId(for technique: TechniqueInfo) -> String {
        technique.hodokuId ?? technique.id.rawValue
    }
}
