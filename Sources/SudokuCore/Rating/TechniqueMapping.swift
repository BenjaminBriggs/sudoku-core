//
//  TechniqueMapping.swift
//  SudokuCore
//
//  Maps internal HintTechnique to external standard identifiers.
//

import Foundation

public enum TechniqueMapping {
    /// Return a stable identifier for SE tables for a given technique.
    /// Placeholder mapping; replace with table-driven ids for full compatibility.
    public static func seId(for technique: HintTechnique) -> String {
        technique.seId
    }

    /// Return a stable identifier for HoDoKu tables for a given technique.
    public static func hodokuId(for technique: HintTechnique) -> String {
        technique.hodokuId
    }
}
