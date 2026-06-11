//
//  KillerSudoku.swift
//  SudokuKiller
//
import Foundation
import SudokuCore

/// Entry point for the killer sudoku variant module.
public enum KillerSudoku {
    /// Registers killer constraint types for decoding. Call once at app startup,
    /// before decoding any killer puzzles. Idempotent.
    public static func register() {
        ConstraintRegistry.register(KillerCage.self)
    }

    /// The killer-specific solving techniques, in solve order.
    /// Combine with the classic set: `ClassicTechniques.all + KillerSudoku.techniques`.
    public static var techniques: [any HintTechnique] {
        [CageLastCell(), CageCombinations()]
    }
}
