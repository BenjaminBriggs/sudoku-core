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
    public static func hasUniqueSolution(_ puzzle: [[Int]]) -> Bool {
        // Use a bitset for better performance (0b111111111 represents digits 1-9)
        typealias Domain = Int
        let FULL_DOMAIN: Domain = 0b111111111 // All 9 digits possible

        // Pre-compute domains for all cells
        var domains = Array(repeating: Array(repeating: FULL_DOMAIN, count: 9), count: 9)

        // Setup initial domains and constraints
        for row in 0..<9 {
            for col in 0..<9 {
                if puzzle[row][col] != 0 {
                    // For fixed cells, domain is just the value
                    let value = puzzle[row][col]
                    let valueDomain = 1 << (value - 1) // Single bit for this value
                    domains[row][col] = valueDomain

                    // Apply constraints to related cells
                    if propagateConstraints(
                        row: row,
                        col: col,
                        value: value,
                        domains: &domains,
                        puzzle: puzzle
                    ) == false {
                        return false // Unsolvable
                    }
                }
            }
        }

        // Try to find a second solution
        return countSolutions(puzzle: puzzle, domains: domains, maxSolutions: 2) == 1
    }

    private static func propagateConstraints(
        row: Int,
        col: Int,
        value: Int,
        domains: inout [[Int]],
        puzzle: [[Int]]
    ) -> Bool {
        let valueMask = ~(1 << (value - 1)) // Mask to remove this value from domains

        // Remove value from row
        for c in 0..<9 where c != col {
            domains[row][c] &= valueMask
            if domains[row][c] == 0 && puzzle[row][c] == 0 {
                return false // Cell has no valid values
            }
        }

        // Remove value from column
        for r in 0..<9 where r != row {
            domains[r][col] &= valueMask
            if domains[r][col] == 0 && puzzle[r][col] == 0 {
                return false // Cell has no valid values
            }
        }

        // Remove value from 3x3 box using lookup table
        let boxIndex = LookupTables.cellToBoxIndex[row][col]
        let boxRow = (boxIndex / 3) * 3
        let boxCol = (boxIndex % 3) * 3

        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                if r != row || c != col {
                    domains[r][c] &= valueMask
                    if domains[r][c] == 0 && puzzle[r][c] == 0 {
                        return false // Cell has no valid values
                    }
                }
            }
        }

        return true
    }

    private static func countSolutions(puzzle: [[Int]], domains: [[Int]], maxSolutions: Int) -> Int {
        var solutionCount = 0
        var workingPuzzle = puzzle
        let workingDomains = domains

        // Find cell with minimum remaining values (MRV)
        switch findMRVCell(in: workingPuzzle, domains: workingDomains) {
        case .solved:
            // No empty cells - we found a solution
            return 1
        case .unsolvable:
            // Encountered a contradiction; no solutions down this branch
            return 0
        case .cell(let row, let col, let values):
            // Try each possible value
            for value in values {
                workingPuzzle[row][col] = value
                // Temporarily apply constraints for this value
                var tempDomains = workingDomains
                let valueDomain = 1 << (value - 1)
                tempDomains[row][col] = valueDomain

                if propagateConstraints(
                    row: row,
                    col: col,
                    value: value,
                    domains: &tempDomains,
                    puzzle: puzzle
                ) {
                    solutionCount += countSolutions(puzzle: workingPuzzle, domains: tempDomains, maxSolutions: maxSolutions - solutionCount)

                    if solutionCount >= maxSolutions {
                        return solutionCount
                    }
                }

                // Restore for next iteration
                workingPuzzle[row][col] = 0
            }

            return solutionCount
        }
    }

    private enum MRVState {
        case solved
        case unsolvable
        case cell(row: Int, col: Int, values: [Int])
    }

    private static func findMRVCell(in puzzle: [[Int]], domains: [[Int]]) -> MRVState {
        var minRow = -1
        var minCol = -1
        var minCount = 10
        var minDomain = 0

        // Iterate through all cells to find MRV
        for row in 0..<9 {
            let puzzleRow = puzzle[row]
            let domainRow = domains[row]

            for col in 0..<9 {
                if puzzleRow[col] == 0 {
                    let domain = domainRow[col]

                    // Early detection of impossible puzzle
                    if domain == 0 {
                        return .unsolvable
                    }

                    let count = domain.nonzeroBitCount

                    if count < minCount {
                        minRow = row
                        minCol = col
                        minCount = count
                        minDomain = domain

                        // Early exit if we find a cell with only one possibility
                        if count == 1 {
                            let values = domainToValues(domain)
                            return .cell(row: minRow, col: minCol, values: values)
                        }
                    }
                }
            }
        }

        if minRow != -1 {
            let values = domainToValues(minDomain)
            return .cell(row: minRow, col: minCol, values: values)
        }

        return .solved
    }

    private static func countBits(_ n: Int) -> Int {
        // Use the built-in nonzeroBitCount for optimal performance
        n.nonzeroBitCount
    }

    private static func domainToValues(_ domain: Int) -> [Int] {
        // Pre-allocate with exact capacity for better performance
        var values: [Int] = []
        values.reserveCapacity(countBits(domain))
        for i in 0..<9 {
            if (domain & (1 << i)) != 0 {
                values.append(i + 1)
            }
        }
        return values
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
