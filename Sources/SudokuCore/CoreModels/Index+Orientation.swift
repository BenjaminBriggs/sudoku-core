//
//  Index+s.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//
import Foundation

extension Puzzle.Index {

    public enum Orientation: CaseIterable {
        case row
        case column
        case house

        public var otherOrientations: [Orientation] {
            switch self {
            case .column:   [.house, .row]
            case .house:    [.column, .row]
            case .row:      [.house, .column]
            }
        }
    }

    public func cells(in orientation: Puzzle.Index.Orientation) -> Set<Puzzle.Index> {
        switch orientation {
        case .column:
            return Set(0..<9)
                .map {
                    Puzzle.Index(
                        row: $0,
                        column: self.column
                    )
                }
                .reduce(into: Set<Puzzle.Index>()) {
                    $0.insert($1)
                }
        case .row:
            return Set(0..<9)
                .map {
                    Puzzle.Index(
                        row: self.row,
                        column: $0
                    )
                }
                .reduce(into: Set<Puzzle.Index>()) {
                    $0.insert($1)
                }
        case .house:
            return Set(houseIndices)
        }
    }
}

extension Puzzle.Index {
    public var houseNumber: Int {
        (row / 3) * 3 + (column / 3)
    }

    public var houseIndices: [Puzzle.Index] {
        var indices: [Puzzle.Index] = []

        let houseRowStart = (row / 3) * 3
        let houseColStart = (column / 3) * 3

        for r in houseRowStart..<(houseRowStart + 3) {
            for c in houseColStart..<(houseColStart + 3) {
                indices.append(Puzzle.Index(row: r, column: c))
            }
        }
        return indices
    }

    public static func cellsInHouse(_ house: Int) -> [Puzzle.Index] {
        let startRow = (house / 3) * 3
        let startCol = (house % 3) * 3
        return (startRow..<startRow+3).flatMap { row in
            (startCol..<startCol+3).map { col in
                Puzzle.Index(row: row, column: col)
            }
        }
    }
}

