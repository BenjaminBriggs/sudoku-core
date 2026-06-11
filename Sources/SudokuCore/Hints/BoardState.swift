//
//  BoardState.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//

import Foundation

public struct BoardState: Sendable, Equatable {
    public var grid: [[Int]]
    public var pencilMarks: [[Set<Int>]]
    public var validOptions: [[Set<Int>]]
    public var solution: [[Int]]?
    /// Additive variant constraints active for this puzzle. Empty for classic.
    public var constraints: [AnyConstraint]

    public init(
        grid: [[Int]] = [],
        pencilMarks: [[Set<Int>]] = [],
        validOptions: [[Set<Int>]] = [],
        solution: [[Int]]? = nil,
        constraints: [AnyConstraint] = []
    ) {
        self.grid = grid
        self.pencilMarks = pencilMarks
        self.validOptions = validOptions
        self.solution = solution
        self.constraints = constraints
    }
}
