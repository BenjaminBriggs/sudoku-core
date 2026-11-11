// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

public enum SudokuValidationError: Error {
    case invalidGridSize
}

public enum Validator {
    public static func isValid(
        _ num: Int,
        row: Int,
        column: Int,
        in grid: [[Int]]
    ) -> Bool {
        if num == 0 { return false }

        var grid = grid
        grid[row][column] = 0

        return isInRow(num, row: row, in: grid) == false
        && isInColumn(num, col: column, in: grid) == false
        && isInHouse(num, row: row, column: column, in: grid) == false
    }

    private static func isInRow(
        _ num: Int,
        row: Int,
        in grid: [[Int]]
    ) -> Bool {
        grid[row].contains(num)
    }

    private static func isInColumn(
        _ num: Int,
        col: Int,
        in grid: [[Int]]
    ) -> Bool {
        (0..<9).contains { grid[$0][col] == num }
    }

    private static func isInHouse(
        _ num: Int,
        row: Int,
        column: Int,
        in grid: [[Int]]
    ) -> Bool {
        let houseRow = row - row % 3
        let houseCol = column - column % 3
        for r in houseRow..<houseRow+3 {
            for c in houseCol..<houseCol+3 {
                if grid[r][c] == num { return true }
            }
        }
        return false
    }
}

extension Validator {
    /// Returns `true` if:
    /// 1) Every cell is non-zero (i.e. filled)
    /// 2) No conflicts in row, column, or house
    ///
    /// This means it's a valid solved Sudoku board.
    public static func isCompleteAndValidSolution(_ grid: [[Int]]) throws -> Bool {
        guard grid.count == 9, grid.allSatisfy({ $0.count == 9 }) else {
            throw SudokuValidationError.invalidGridSize
        }

        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 { return false }
            }
        }
        // Then check no conflicts
        return hasNoConflicts(in: grid)
    }
}

extension Validator {
    /// Returns `true` if there are *no* conflicts in any row, column, or house.
    /// i.e., each non-zero digit appears at most once per row/col/house.
    /// Optimized version using bitsets for faster duplicate detection.
    public static func hasNoConflicts(in grid: [[Int]]) -> Bool {
        // Optionally: check dimension 9x9
        guard grid.count == 9, grid.allSatisfy({ $0.count == 9 }) else { return false }

        // Check all rows
        for row in 0..<9 {
            var seen = 0
            for col in 0..<9 {
                let val = grid[row][col]
                if val != 0 {
                    let bit = 1 << (val - 1)
                    if (seen & bit) != 0 {
                        return false
                    }
                    seen |= bit
                }
            }
        }

        // Check all columns
        for col in 0..<9 {
            var seen = 0
            for row in 0..<9 {
                let val = grid[row][col]
                if val != 0 {
                    let bit = 1 << (val - 1)
                    if (seen & bit) != 0 {
                        return false
                    }
                    seen |= bit
                }
            }
        }

        // Check all 3x3 houses
        for houseRow in stride(from: 0, to: 9, by: 3) {
            for houseCol in stride(from: 0, to: 9, by: 3) {
                var seen = 0
                for r in houseRow..<(houseRow + 3) {
                    for c in houseCol..<(houseCol + 3) {
                        let val = grid[r][c]
                        if val != 0 {
                            let bit = 1 << (val - 1)
                            if (seen & bit) != 0 {
                                return false
                            }
                            seen |= bit
                        }
                    }
                }
            }
        }

        return true
    }

    private static func hasDuplicateInRow(_ row: Int, grid: [[Int]]) -> Bool {
        var seen = 0
        for col in 0..<9 {
            let val = grid[row][col]
            if val != 0 {
                let bit = 1 << (val - 1)
                if (seen & bit) != 0 {
                    return true
                }
                seen |= bit
            }
        }
        return false
    }

    private static func hasDuplicateInColumn(_ col: Int, grid: [[Int]]) -> Bool {
        var seen = 0
        for row in 0..<9 {
            let val = grid[row][col]
            if val != 0 {
                let bit = 1 << (val - 1)
                if (seen & bit) != 0 {
                    return true
                }
                seen |= bit
            }
        }
        return false
    }

    private static func hasDuplicateInHouse(houseRow: Int, houseCol: Int, grid: [[Int]]) -> Bool {
        var seen = 0
        for r in houseRow..<(houseRow + 3) {
            for c in houseCol..<(houseCol + 3) {
                let val = grid[r][c]
                if val != 0 {
                    let bit = 1 << (val - 1)
                    if (seen & bit) != 0 {
                        return true
                    }
                    seen |= bit
                }
            }
        }
        return false
    }
}

extension Validator {
    /// Whether the puzzle has exactly one solution. Clues that clash, grids that aren't 9×9
    /// and digits outside 0…9 have none.
    ///
    /// The yes-or-no form of ``solutionCount(of:)``, which also returns the solutions it finds.
    public static func hasUniqueSolution(_ puzzle: [[Int]]) -> Bool {
        countSolutions(of: puzzle, limit: 2) == 1
    }
}

extension Validator {
    /// Optimized version using bitsets for better performance
    /// Each bitset represents digits 1-9 as bits 0-8
    public static func validOptions(for grid: [[Int]]) -> [[Set<Int>]] {
        // Pre-allocate result array
        var validOptions: [[Set<Int>]] = Array(repeating: Array(repeating: [], count: 9), count: 9)

        // Track used digits per row, column, and box using bitsets
        var rowUsed = Array(repeating: 0, count: 9)
        var colUsed = Array(repeating: 0, count: 9)
        var boxUsed = Array(repeating: 0, count: 9)

        // First pass: build bitsets of used digits
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

        // Second pass: compute valid options using bitwise operations
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] != 0 {
                    validOptions[row][col] = []
                } else {
                    let boxIndex = (row / 3) * 3 + (col / 3)
                    // Combine all constraints with bitwise OR
                    let used = rowUsed[row] | colUsed[col] | boxUsed[boxIndex]

                    // Get available digits (invert the used bits, mask to 9 bits)
                    let available = (~used) & 0b111111111

                    // Use pre-computed lookup table for bitset to Set conversion
                    validOptions[row][col] = LookupTables.bitsetToSet[available]
                }
            }
        }

        return validOptions
    }

}
