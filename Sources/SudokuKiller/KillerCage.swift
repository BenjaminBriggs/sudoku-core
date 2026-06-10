//
//  KillerCage.swift
//  SudokuKiller
//
import Foundation
import SudokuCore

/// A killer sudoku cage: a group of cells whose digits are all different and
/// sum to a target.
public struct KillerCage: Sendable, Codable, Hashable {
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
