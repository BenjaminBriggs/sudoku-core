//
//  Index+Neighbours.swift
//  SudokuUtilities
//
//  Created by Benjamin Briggs on 14/02/2025.
//
import Foundation

extension Puzzle {
    public enum Direction: CaseIterable {
        case top, bottom, left, right
        case topRight, topLeft, bottomRight, bottomLeft
    }
}

extension Puzzle.Index {
    public var allNeighbours: [Puzzle.Index] {
        [
            neighbour(in: .right),
            neighbour(in: .left),
            neighbour(in: .top),
            neighbour(in: .bottom)
        ].compactMap { $0 }
    }

    public func neighbour(in direction: Puzzle.Direction) -> Puzzle.Index? {
        switch direction {
        case .right:
            if column == 8 { return nil }
            return Puzzle.Index(row: row, column: column + 1)
        case .left:
            if column == 0 { return nil }
            return Puzzle.Index(row: row, column: column - 1)
        case .top:
            if row == 0 { return nil }
            return Puzzle.Index(row: row - 1, column: column)
        case .bottom:
            if row == 8 { return nil }
            return Puzzle.Index(row: row + 1, column: column)
        case .topRight:
            if row == 0 { return nil }
            if column == 8 { return nil }
            return Puzzle.Index(row: row - 1, column: column + 1)
        case .topLeft:
            if row == 0 { return nil }
            if column == 0 { return nil }
            return Puzzle.Index(row: row - 1, column: column - 1)
        case .bottomRight:
            if row == 8 { return nil }
            if column == 8 { return nil }
            return Puzzle.Index(row: row + 1, column: column + 1)
        case .bottomLeft:
            if row == 8 { return nil }
            if column == 0 { return nil }
            return Puzzle.Index(row: row + 1, column: column - 1)
        }
    }
}
