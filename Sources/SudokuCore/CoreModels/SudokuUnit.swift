//
//  SudokuUnit.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//


public enum SudokuUnit: Hashable, Sendable, Codable {
    case row(Int), column(Int), house(Int)
}

extension SudokuUnit {
    /// Creates a unit from an orientation and line index (house index for `.house`).
    public init(orientation: Puzzle.Index.Orientation, index: Int) {
        switch orientation {
        case .row:    self = .row(index)
        case .column: self = .column(index)
        case .house:  self = .house(index)
        }
    }
}

extension SudokuUnit {
    public var orientation: Puzzle.Index.Orientation {
        switch self {
        case .row:
            return .row
        case .column:
            return .column
        case .house:
            return .house
        }
    }
}

extension SudokuUnit {
    /// Optimized to use pre-computed lookup tables
    public var allPositionsInOrientation: [Puzzle.Index] {
        switch self {
        case .row(let row):
            LookupTables.rowCells[row]
        case .column(let col):
            LookupTables.columnCells[col]
        case .house(let house):
            LookupTables.boxCells[house]
        }
    }

    /// Convenience property - same as allPositionsInOrientation
    public var positions: [Puzzle.Index] {
        allPositionsInOrientation
    }
}

extension SudokuUnit {
    /// All 9 rows (pre-computed)
    public static let allRows: [SudokuUnit] = [
        .row(0), .row(1), .row(2), .row(3), .row(4), .row(5), .row(6), .row(7), .row(8)
    ]

    /// All 9 columns (pre-computed)
    public static let allColumns: [SudokuUnit] = [
        .column(0), .column(1), .column(2), .column(3), .column(4), .column(5), .column(6), .column(7), .column(8)
    ]

    /// All 9 houses (pre-computed)
    public static let allHouses: [SudokuUnit] = [
        .house(0), .house(1), .house(2), .house(3), .house(4), .house(5), .house(6), .house(7), .house(8)
    ]

    /// All units (27 total: 9 rows + 9 columns + 9 houses) (pre-computed)
    public static let allUnits: [SudokuUnit] = {
        var units: [SudokuUnit] = []
        units.reserveCapacity(27)
        units.append(contentsOf: allRows)
        units.append(contentsOf: allColumns)
        units.append(contentsOf: allHouses)
        return units
    }()
}
