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

    public init(
        grid: [[Int]] = [],
        pencilMarks: [[Set<Int>]] = [],
        validOptions: [[Set<Int>]] = [],
        solution: [[Int]]? = nil
    ) {
        self.grid = grid
        self.pencilMarks = pencilMarks
        self.validOptions = validOptions
        self.solution = solution
    }
}
