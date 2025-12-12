//
//  SolutionGenerator.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation

/// A helper enum that specializes in creating fully filled Sudoku solutions.
/// The resulting grid is guaranteed to be valid (no row/col/box duplicates).
public enum SolutionGenerator {

    /// Generates a random, fully solved Sudoku solution by filling an empty 9x9 grid
    /// using backtracking and random digit order.
    ///
    /// - Returns: A 9x9 grid (Solution) with digits 1..9 in each cell, obeying Sudoku constraints.
    public static func generateRandomSolution() -> [[Int]] {
        var grid = Solution.empty()
        // Repeatedly attempt to fill the grid until successful (though typically 1 attempt is enough).
        // The fillWithBacktracking() call returns true if it managed to fill the entire grid.
        while !fillWithBacktracking(&grid) {
            grid = Solution.empty()
        }
        return grid
    }

    // MARK: - Internal Helpers

    /// Recursively fills the `grid` in place with digits 1..9,
    /// ensuring no row/column/box conflicts. Returns `true` if fully filled.
    /// Optimized version using bitsets to track used digits.
    private static func fillWithBacktracking(_ grid: inout [[Int]]) -> Bool {
        var rowUsed = Array(repeating: 0, count: 9)
        var colUsed = Array(repeating: 0, count: 9)
        var boxUsed = Array(repeating: 0, count: 9)

        // Pre-compute used digits from any pre-filled cells
        for row in 0..<9 {
            for col in 0..<9 {
                let value = grid[row][col]
                if value != 0 {
                    let bit = 1 << (value - 1)
                    rowUsed[row] |= bit
                    colUsed[col] |= bit
                    let boxIndex = (row / 3) * 3 + (col / 3)
                    boxUsed[boxIndex] |= bit
                }
            }
        }

        return fillWithBacktrackingOptimized(
            &grid,
            rowUsed: &rowUsed,
            colUsed: &colUsed,
            boxUsed: &boxUsed,
            cell: 0
        )
    }

    /// Optimized backtracking that uses bitsets and a cell index instead of nested loops.
    private static func fillWithBacktrackingOptimized(
        _ grid: inout [[Int]],
        rowUsed: inout [Int],
        colUsed: inout [Int],
        boxUsed: inout [Int],
        cell: Int
    ) -> Bool {
        // If we've filled all 81 cells, we're done
        if cell == 81 {
            return true
        }

        let row = cell / 9
        let col = cell % 9

        // If this cell is already filled, move to next
        if grid[row][col] != 0 {
            return fillWithBacktrackingOptimized(
                &grid,
                rowUsed: &rowUsed,
                colUsed: &colUsed,
                boxUsed: &boxUsed,
                cell: cell + 1
            )
        }

        let boxIndex = (row / 3) * 3 + (col / 3)
        let used = rowUsed[row] | colUsed[col] | boxUsed[boxIndex]

        // Try digits 1..9 in random order
        for num in (1...9).shuffled() {
            let bit = 1 << (num - 1)

            // Check if this digit is already used
            if (used & bit) == 0 {
                // Place the digit
                grid[row][col] = num
                rowUsed[row] |= bit
                colUsed[col] |= bit
                boxUsed[boxIndex] |= bit

                // Recurse to next cell
                if fillWithBacktrackingOptimized(
                    &grid,
                    rowUsed: &rowUsed,
                    colUsed: &colUsed,
                    boxUsed: &boxUsed,
                    cell: cell + 1
                ) {
                    return true
                }

                // Backtrack
                grid[row][col] = 0
                rowUsed[row] &= ~bit
                colUsed[col] &= ~bit
                boxUsed[boxIndex] &= ~bit
            }
        }

        return false
    }
}
