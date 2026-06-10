//
//  KillerCage.swift
//  SudokuKiller
//
import Foundation
import SudokuCore

/// A killer sudoku cage: a group of cells whose digits are all different and
/// sum to a target.
public struct KillerCage: Constraint {
    public let cells: [Puzzle.Index]
    public let sum: Int

    public init(cells: [Puzzle.Index], sum: Int) {
        self.cells = cells
        self.sum = sum
    }

    /// All sets of `size` distinct digits from 1...9, none in `excluding`,
    /// summing to `sum`.
    static func combinations(size: Int, sum: Int, excluding: Set<Int>) -> [Set<Int>] {
        let available = (1...9).filter { excluding.contains($0) == false }
        var results: [Set<Int>] = []
        var current: [Int] = []

        func search(from index: Int, remaining: Int, slots: Int) {
            if slots == 0 {
                if remaining == 0 { results.append(Set(current)) }
                return
            }
            for i in index..<available.count {
                let digit = available[i]
                if digit > remaining { break }
                current.append(digit)
                search(from: i + 1, remaining: remaining - digit, slots: slots - 1)
                current.removeLast()
            }
        }

        search(from: 0, remaining: sum, slots: size)
        return results
    }
}

extension KillerCage {
    public static let typeID = "killerCage"

    public func violations(in state: BoardState) -> [ConstraintViolation] {
        var placed: [Int] = []
        var emptyCount = 0
        for cell in cells {
            let value = state.grid[cell.row][cell.column]
            if value == 0 { emptyCount += 1 } else { placed.append(value) }
        }

        let placedSum = placed.reduce(0, +)
        let hasDuplicate = Set(placed).count != placed.count
        let exceedsSum = placedSum > sum || (emptyCount == 0 && placedSum != sum)
        // Partial cages can also be definitely broken: each empty cell adds at least 1.
        let cannotReachValidSum = emptyCount > 0 && placedSum + emptyCount > sum

        if hasDuplicate || exceedsSum || cannotReachValidSum {
            return [ConstraintViolation(constraintTypeID: Self.typeID, cells: cells)]
        }
        return []
    }

    public func prune(candidates: inout PencilMarks, in state: BoardState) {
        var placedDigits: Set<Int> = []
        var placedSum = 0
        var emptyCells: [Puzzle.Index] = []
        for cell in cells {
            let value = state.grid[cell.row][cell.column]
            if value == 0 {
                emptyCells.append(cell)
            } else {
                placedDigits.insert(value)
                placedSum += value
            }
        }
        guard emptyCells.isEmpty == false else { return }

        let combos = Self.combinations(
            size: emptyCells.count,
            sum: sum - placedSum,
            excluding: placedDigits
        )
        let allowed = combos.reduce(into: Set<Int>()) { $0.formUnion($1) }
        for cell in emptyCells {
            candidates[cell.row][cell.column].formIntersection(allowed)
        }
    }
}
