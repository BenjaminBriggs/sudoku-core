//
//  SudokuGenerator.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//


import Foundation

/// Simplified Sudoku generator that focuses only on generating valid puzzles
public enum SudokuGenerator {
    /// Generate a Sudoku puzzle with an approximate target difficulty
    /// - Parameters:
    ///   - targetsEmptyCells: The target number of empty cells (higher = harder typically)
    ///   - solution: An optional pregenerated solution to use
    /// - Returns: Tuple with the solution and starting state grid
    public static func generatePuzzle(
        targetsEmptyCells: ClosedRange<Int> = 45...55,
        from solution: [[Int]] = SolutionGenerator.generateRandomSolution()
    ) async -> (solution: [[Int]], startingState: [[Int]]) {
        let puzzle = await createPuzzle(from: solution, targetEmpty: Int.random(in: targetsEmptyCells))
        return (solution, puzzle)
    }
    
    /// Generate a Sudoku puzzle by removing cells from a solution
    /// - Parameters:
    ///   - solution: The complete Sudoku solution
    ///   - targetEmptyCells: Range of empty cells to target
    ///   - cellsOrder: Optional predetermined removal order (useful for tests)
    ///   - uniqueCheck: Custom uniqueness validator (defaults to `Validator.hasUniqueSolution`)
    /// - Returns: A puzzle grid with some cells removed
    public static func createPuzzle(
        from solution: [[Int]],
        targetEmpty: Int = Int.random(in: 25...42),
        cellsOrder: [Puzzle.Index]? = nil,
        uniqueCheck: (_ puzzle: [[Int]]) -> Bool = Validator.hasUniqueSolution
    ) async -> [[Int]] {
        var puzzle = solution
        var cells = cellsOrder ?? Puzzle.Index.allIndices
        if cellsOrder == nil {
            cells.shuffle()
        }

        var removedCells: [(index: Puzzle.Index, value: Int)] = []
        removedCells.reserveCapacity(targetEmpty)

        // Try to remove cells up to the target
        var attemptedCells = 0
        let maxAttempts = min(81, cells.count)
        let checkpointInterval = 5
        var pendingBatch: [(index: Puzzle.Index, value: Int)] = []
        pendingBatch.reserveCapacity(checkpointInterval)

        while removedCells.count < targetEmpty && attemptedCells < maxAttempts {
            let index = cells[attemptedCells]
            attemptedCells += 1

            let originalValue = puzzle[index.row][index.column]

            // Try removing this cell
            puzzle[index.row][index.column] = 0
            pendingBatch.append((index, originalValue))

            let shouldValidate = pendingBatch.count == checkpointInterval || attemptedCells == maxAttempts
            if shouldValidate {
                if uniqueCheck(puzzle) {
                    commitPendingBatch(
                        &pendingBatch,
                        into: &removedCells,
                        updating: &puzzle,
                        targetEmpty: targetEmpty
                    )
                } else {
                    // Restore only the removals that break uniqueness
                    while let last = pendingBatch.last {
                        puzzle[last.index.row][last.index.column] = last.value
                        pendingBatch.removeLast()
                        if uniqueCheck(puzzle) {
                            break
                        }
                    }

                    commitPendingBatch(
                        &pendingBatch,
                        into: &removedCells,
                        updating: &puzzle,
                        targetEmpty: targetEmpty
                    )
                }

                if removedCells.count >= targetEmpty {
                    break
                }
            }
        }

        // Handle any remaining pending cells
        if pendingBatch.isEmpty == false {
            if uniqueCheck(puzzle) == false {
                while let last = pendingBatch.last {
                    puzzle[last.index.row][last.index.column] = last.value
                    pendingBatch.removeLast()
                    if uniqueCheck(puzzle) {
                        break
                    }
                }
            }

            commitPendingBatch(
                &pendingBatch,
                into: &removedCells,
                updating: &puzzle,
                targetEmpty: targetEmpty
            )
        }

        return puzzle
    }

    private static func commitPendingBatch(
        _ pendingBatch: inout [(index: Puzzle.Index, value: Int)],
        into removedCells: inout [(index: Puzzle.Index, value: Int)],
        updating puzzle: inout [[Int]],
        targetEmpty: Int
    ) {
        guard pendingBatch.isEmpty == false else { return }

        let remainingSlots = max(0, targetEmpty - removedCells.count)
        if remainingSlots == 0 {
            for cell in pendingBatch {
                puzzle[cell.index.row][cell.index.column] = cell.value
            }
            pendingBatch.removeAll(keepingCapacity: true)
            return
        }

        if remainingSlots < pendingBatch.count {
            let overflow = pendingBatch[remainingSlots...]
            for cell in overflow {
                puzzle[cell.index.row][cell.index.column] = cell.value
            }
            pendingBatch.removeSubrange(remainingSlots..<pendingBatch.count)
        }

        removedCells.append(contentsOf: pendingBatch)
        pendingBatch.removeAll(keepingCapacity: true)
    }
}
