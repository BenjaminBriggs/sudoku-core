//
//  BoardHelpers.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 05/02/2025.
//
import Foundation

extension Board {
    public func cell(at position: Puzzle.Index) -> Board.Cell {
        let cell = cells[position.row * 9 + position.column]
        assert(cell.position == position)
        return cell
    }

    // all the houses on the board
    public var allHouses: [[Puzzle.Index]] {
        var houses = [[Puzzle.Index]]()
        Puzzle.Index.allIndices.forEach { position in
            if houses.contains(where: { $0.contains(position) }) == false {
                let indices = position.houseIndices
                houses.append(indices)
            }
        }
        return houses
    }

    // Helper to check if all positions share the same box
    func commonHouse(for positions: [Puzzle.Index]) -> [Puzzle.Index]? {
        guard let firstPos = positions.first else { return nil }
        let firstBox = firstPos.houseIndices
        guard positions.allSatisfy({ $0.houseIndices == firstBox }) else { return nil }
        return firstBox
    }

    // Helper to get box number (1-9)
    func boxNumber(for position: Puzzle.Index) -> Int {
        (position.row / 3) * 3 + (position.column / 3) + 1
    }

    public func cellPositions(with number: Int) -> Set<Puzzle.Index> {
        cells
            .filter { $0.value == number}
            .reduce(into: Set<Puzzle.Index>()) { $0.insert($1.position) }
    }

    public func cellValid(at cell: Board.Cell) -> Bool {
        guard let value = cell.value else { return true }
        return Validator
            .isValid(
                value,
                row: cell.position.row,
                column: cell.position.column,
                in: cells.solution
            )
    }

    public func cellComplete(at cell: Board.Cell) -> Bool {
        completedRows.contains(cell.position.row) ||
        completedColumns.contains(cell.position.column) ||
        completedHouses.contains(cell.position.houseNumber) ||
        completedNumbers.contains(cell.value ?? 0)
    }
}
