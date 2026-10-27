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
    /// Whether the puzzle is known to have exactly one solution. The uniqueness techniques
    /// (Unique Rectangles and BUG) are only sound when it does, so they stay silent otherwise.
    public var assumesUniqueSolution: Bool

    public init(
        grid: [[Int]] = [],
        pencilMarks: [[Set<Int>]] = [],
        validOptions: [[Set<Int>]] = [],
        solution: [[Int]]? = nil,
        assumesUniqueSolution: Bool = false
    ) {
        self.grid = grid
        self.pencilMarks = pencilMarks
        self.validOptions = validOptions
        self.solution = solution
        self.assumesUniqueSolution = assumesUniqueSolution
    }
}
