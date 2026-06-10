//
//  Checking.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation

extension Board {
    public var isValid: Bool {
        Validator.hasNoConflicts(in: cells.solution)
    }
}
