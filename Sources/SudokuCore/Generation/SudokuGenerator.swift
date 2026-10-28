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
    ///   - symmetry: The symmetry the clue layout keeps (defaults to `.none`)
    /// - Returns: Tuple with the solution and starting state grid
    public static func generatePuzzle(
        targetsEmptyCells: ClosedRange<Int> = 45...55,
        from solution: [[Int]] = SolutionGenerator.generateRandomSolution(),
        symmetry: Symmetry = .none
    ) async -> (solution: [[Int]], startingState: [[Int]]) {
        let puzzle = await createPuzzle(
            from: solution,
            targetEmpty: Int.random(in: targetsEmptyCells),
            symmetry: symmetry
        )
        return (solution, puzzle)
    }
    
    /// Generate a Sudoku puzzle by removing cells from a solution
    /// - Parameters:
    ///   - solution: The complete Sudoku solution
    ///   - targetEmptyCells: Range of empty cells to target
    ///   - cellsOrder: Optional predetermined removal order (useful for tests)
    ///   - symmetry: The symmetry the clue layout keeps. Anything but `.none` removes whole
    ///     orbits, so the result may stop short of `targetEmpty` by up to an orbit's size.
    ///   - uniqueCheck: Custom uniqueness validator (defaults to `Validator.hasUniqueSolution`)
    /// - Returns: A puzzle grid with some cells removed
    public static func createPuzzle(
        from solution: [[Int]],
        targetEmpty: Int = Int.random(in: 25...42),
        cellsOrder: [Puzzle.Index]? = nil,
        symmetry: Symmetry = .none,
        uniqueCheck: (_ puzzle: [[Int]]) -> Bool = Validator.hasUniqueSolution
    ) async -> [[Int]] {
        if symmetry != .none {
            return createSymmetricPuzzle(
                from: solution,
                targetEmpty: targetEmpty,
                cellsOrder: cellsOrder,
                symmetry: symmetry,
                uniqueCheck: uniqueCheck
            )
        }

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

    /// Removes one more orbit of givens from `puzzle`, keeping it unique.
    ///
    /// Used to push a symmetric puzzle harder after rating it.
    /// - Returns: The puzzle with one orbit removed, or `nil` when no orbit can go.
    public static func removingOrbit(
        from puzzle: [[Int]],
        symmetry: Symmetry,
        uniqueCheck: (_ puzzle: [[Int]]) -> Bool = Validator.hasUniqueSolution
    ) -> [[Int]]? {
        var candidate = puzzle
        for orbit in symmetry.orbits.shuffled() {
            guard orbit.allSatisfy({ puzzle[$0.row][$0.column] != 0 }) else { continue }
            for cell in orbit {
                candidate[cell.row][cell.column] = 0
            }
            if uniqueCheck(candidate) {
                return candidate
            }
            for cell in orbit {
                candidate[cell.row][cell.column] = puzzle[cell.row][cell.column]
            }
        }
        return nil
    }

    /// Removes whole orbits so the clue layout keeps `symmetry`.
    ///
    /// Each orbit is checked on its own rather than batched: orbits are already 2–4 cells,
    /// and a failed batch would have to back off an orbit at a time anyway.
    private static func createSymmetricPuzzle(
        from solution: [[Int]],
        targetEmpty: Int,
        cellsOrder: [Puzzle.Index]?,
        symmetry: Symmetry,
        uniqueCheck: (_ puzzle: [[Int]]) -> Bool
    ) -> [[Int]] {
        var puzzle = solution
        let orbits: [[Puzzle.Index]]
        if let cellsOrder {
            // Orbits in order of their first cell in `cellsOrder`
            var seen = Set<Puzzle.Index>()
            orbits = cellsOrder.compactMap { index in
                guard seen.contains(index) == false else { return nil }
                let orbit = symmetry.orbit(of: index)
                seen.formUnion(orbit)
                return orbit
            }
        } else {
            orbits = symmetry.orbits.shuffled()
        }

        var emptyCount = 0
        for orbit in orbits {
            if emptyCount >= targetEmpty { break }
            guard emptyCount + orbit.count <= targetEmpty else { continue }

            for cell in orbit {
                puzzle[cell.row][cell.column] = 0
            }
            if uniqueCheck(puzzle) {
                emptyCount += orbit.count
            } else {
                for cell in orbit {
                    puzzle[cell.row][cell.column] = solution[cell.row][cell.column]
                }
            }
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
