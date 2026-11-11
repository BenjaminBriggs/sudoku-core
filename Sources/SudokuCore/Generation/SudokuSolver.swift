//
//  SudokuSolver.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//
import Foundation

/// Solves a grid of clues by search, with no human-style techniques: the same backtracking
/// search that counts solutions for ``Validator``.
public enum SudokuSolver {
    /// Solves the grid, returning a solution and how much work finding it took.
    ///
    /// Clues that clash, grids that aren't 9×9 and digits outside 0…9 have no solution. A grid
    /// with several solutions gives the first the search reaches, trying the lowest digit
    /// first, which is the same one every time.
    /// - Returns: The solution, if there is one, and the squares the search filled, counting
    ///   every attempt: one more than the grid's empty squares when it never had to back up.
    public static func solve(grid: [[Int]]) -> (solution: [[Int]]?, callCount: Int) {
        guard var search = BitsetSearch(grid: grid) else { return (nil, 0) }
        let solution = search.solutions(limit: 1).first
        return (solution, search.nodes)
    }
}
