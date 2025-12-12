//
//  SudokuSolver.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//
import Foundation

/// A Sudoku solver using Arc Consistency and domain splitting
public enum SudokuSolver {
    /// Domain represents the possible values for each cell in the grid
    private typealias Domain = Set<Int>
    private typealias DomainGrid = [[Domain]]
    

    /// Solve the Sudoku and return the solution along with the call count
    /// - Returns: Tuple with the solution (if found) and the number of AC calls
    public static func solve(grid: [[Int]]) -> (solution: [[Int]]?, callCount: Int) {

        /// The current domains for each cell
        var domains: DomainGrid = Array(
            repeating: Array(repeating: Set<Int>(), count: 9),
            count: 9
        )

        // Setup initial domains based on the grid
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] != 0 {
                    // For filled cells, domain is just the value
                    domains[row][col] = [grid[row][col]]
                } else {
                    // For empty cells, domain is 1-9
                    domains[row][col] = Set(1...9)
                }
            }
        }

        // Reset call count
        var acCallCount = 0

        // Create a copy of domains for backtracking
        var workingDomains = domains
        
        // Apply initial Arc Consistency
        if applyArcConsistency(
            domains: &workingDomains,
            callCount: &acCallCount
        ) == false {
            // Unsolvable puzzle
            return (nil, acCallCount)
        }
        
        // Check if the puzzle is already solved by Arc Consistency alone
        let initialSolution = extractSolution(from: workingDomains, in: grid)
        if isSolutionComplete(initialSolution) {
            return (initialSolution, acCallCount)
        }
        
        // If not solved, use domain splitting with Arc Consistency
        if let solution = solveWithDomainSplitting(
            domains: workingDomains,
            in: grid,
            callCount: &acCallCount
        ) {
            return (solution, acCallCount)
        }
        
        // No solution found
        return (nil, acCallCount)
    }
    
    /// Apply Arc Consistency to reduce domains
    /// - Parameter domains: The domains to apply Arc Consistency to
    /// - Returns: True if the grid is still solvable, false otherwise
    private static func applyArcConsistency(domains: inout DomainGrid, callCount: inout Int) -> Bool {
        // Increment call count
        callCount += 1

        // Use array for queue (faster than removing first element each time)
        var queue: [(row: Int, col: Int)] = []
        queue.reserveCapacity(81)
        var queueIndex = 0

        // Initially add all cells to the queue
        for row in 0..<9 {
            for col in 0..<9 {
                queue.append((row, col))
            }
        }

        // Process queue until empty
        while queueIndex < queue.count {
            let (row, col) = queue[queueIndex]
            queueIndex += 1

            // Periodically cleanup queue to prevent unbounded growth
            if queueIndex > 100 && queueIndex > queue.count / 2 {
                queue.removeFirst(queueIndex)
                queueIndex = 0
            }

            // Skip if cell is already determined
            if domains[row][col].count <= 1 {
                continue
            }

            // Process all constraints for this cell (row, column, box)
            if processConstraints(forRow: row, column: col, domains: &domains, queue: &queue) {
                // If domain becomes empty, puzzle is unsolvable
                if domains[row][col].isEmpty {
                    return false
                }
            }
        }

        return true
    }
    
    /// Process constraints for a cell, removing invalid values
    /// - Parameters:
    ///   - row: The row of the cell
    ///   - column: The column of the cell
    ///   - domains: The current domain grid
    ///   - queue: The queue for arc consistency processing
    /// - Returns: True if the domain was reduced, false otherwise
    private static func processConstraints(
        forRow row: Int,
        column col: Int,
        domains: inout DomainGrid,
        queue: inout [(row: Int, col: Int)]
    ) -> Bool {
        var domainChanged = false

        // Get the current domain
        var cellDomain = domains[row][col]
        let originalCount = cellDomain.count

        // Check row constraint
        for c in 0..<9 where c != col {
            if domains[row][c].count == 1, let value = domains[row][c].first {
                cellDomain.remove(value)
            }
        }

        // Check column constraint
        for r in 0..<9 where r != row {
            if domains[r][col].count == 1, let value = domains[r][col].first {
                cellDomain.remove(value)
            }
        }

        // Check box constraint using lookup table
        let boxIndex = LookupTables.cellToBoxIndex[row][col]
        let boxCells = LookupTables.boxCells[boxIndex]
        for cell in boxCells {
            let r = cell.row
            let c = cell.column
            if (r != row || c != col) && domains[r][c].count == 1, let value = domains[r][c].first {
                cellDomain.remove(value)
            }
        }

        // Check if domain has changed
        if cellDomain.count != originalCount {
            domainChanged = true
            domains[row][col] = cellDomain

            // If it's reduced to a single value, add affected cells to the queue
            if cellDomain.count == 1 {
                // Add affected cells using lookup tables
                let neighbours = LookupTables.cellNeighbours[row][col]
                for neighbour in neighbours {
                    if domains[neighbour.row][neighbour.column].count > 1 {
                        queue.append((row: neighbour.row, col: neighbour.column))
                    }
                }
            }
        }

        return domainChanged
    }
    
    /// Extract the current solution from domains
    /// - Parameter domains: The domain grid
    /// - Returns: The solution based on current domains
    private static func extractSolution(from domains: DomainGrid, in grid: [[Int]]) -> [[Int]] {
        var solution = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        
        for row in 0..<9 {
            for col in 0..<9 {
                if domains[row][col].count == 1, let value = domains[row][col].first {
                    solution[row][col] = value
                } else if grid[row][col] != 0 {
                    // Preserve original values
                    solution[row][col] = grid[row][col]
                }
            }
        }
        
        return solution
    }
    
    /// Check if a solution is complete (no zeros)
    /// - Parameter solution: The solution to check
    /// - Returns: True if the solution is complete
    private static func isSolutionComplete(_ solution: [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if solution[row][col] == 0 {
                    return false
                }
            }
        }
        return true
    }
    
    /// Find the cell with minimum remaining values for domain splitting
    /// - Parameter domains: The domain grid
    /// - Returns: Tuple with row, column, and domain values for MRV cell
    private static func findMRVCell(in domains: DomainGrid) -> (row: Int, col: Int, values: [Int])? {
        var minRow = -1
        var minCol = -1
        var minCount = 10
        
        for row in 0..<9 {
            for col in 0..<9 {
                let count = domains[row][col].count
                if count > 1 && count < minCount {
                    minRow = row
                    minCol = col
                    minCount = count
                }
            }
        }
        
        if minRow != -1 {
            return (minRow, minCol, Array(domains[minRow][minCol]))
        }
        
        return nil
    }
    
    /// Solve using domain splitting combined with Arc Consistency
    /// - Parameter domains: The current domain grid
    /// - Returns: Solution if found, nil otherwise
    private static func solveWithDomainSplitting(
        domains: DomainGrid,
        in grid: [[Int]],
        callCount: inout Int
    ) -> [[Int]]? {
        // Find cell with minimum remaining values
        guard let (row, col, values) = findMRVCell(in: domains) else {
            // No cell with multiple values found, puzzle should be solved
            return extractSolution(from: domains, in: grid)
        }
        
        // Try each value in the domain
        for value in values {
            // Create a copy of domains for this branch
            var branchDomains = domains
            
            // Set the domain to this single value
            branchDomains[row][col] = [value]
            
            // Apply Arc Consistency
            if applyArcConsistency(
                domains: &branchDomains,
                callCount: &callCount
            ) {
                // Recursively solve
                if let solution = solveWithDomainSplitting(
                    domains: branchDomains,
                    in: grid,
                    callCount: &callCount
                ) {
                    return solution
                }
            }
            
            // If this value didn't work, try the next one
        }
        
        // If no value worked, puzzle is unsolvable
        return nil
    }
}
