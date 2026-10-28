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
    /// Whether the givens have exactly one solution under classic rules alone. The uniqueness
    /// techniques (Unique Rectangles and BUG) are only sound when they do, so they stay silent
    /// otherwise. Don't set it because constraints make a puzzle unique: a deadly pattern that
    /// breaks a constraint isn't a second solution, so the uniqueness argument fails.
    public var assumesUniqueSolution: Bool

    public init(
        grid: [[Int]] = [],
        pencilMarks: [[Set<Int>]] = [],
        validOptions: [[Set<Int>]] = [],
        solution: [[Int]]? = nil,
        constraints: [AnyConstraint] = [],
        assumesUniqueSolution: Bool = false
    ) {
        self.grid = grid
        self.pencilMarks = pencilMarks
        self.validOptions = validOptions
        self.solution = solution
        self.constraints = constraints
        self.assumesUniqueSolution = assumesUniqueSolution
    }
}
