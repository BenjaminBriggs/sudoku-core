//
//  Board+Validation.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//
import Foundation

extension Board {
    public func updateCellValidation() {
        updateCellValidation(grid: currentGrid)
    }

    internal func updateCellValidation(grid: [[Int]]) {
        var validOptions = Validator.validOptions(for: grid)
        if constraints.isEmpty == false {
            let snapshot = BoardState(
                grid: grid,
                pencilMarks: validOptions,
                validOptions: validOptions,
                solution: solution,
                constraints: constraints
            )
            for constraint in constraints {
                constraint.base.prune(candidates: &validOptions, in: snapshot)
            }
            constraintViolations = constraints.flatMap { $0.base.violations(in: snapshot) }
        }
        for (index, cell) in self.cells.enumerated() {
            self.cells[index].validOptions = validOptions[cell.position.row][cell.position.column]
        }
    }

    /// Recomputes cell validation and completed-set tracking sharing a single
    /// grid snapshot, instead of rebuilding the grid for each step.
    internal func refreshDerivedState() {
        let grid = currentGrid
        updateCellValidation(grid: grid)
        updateCompletedSets(grid: grid)
    }

    public func updatePencilMarks() {
        noteUpdates += 1
        for (index, cell) in self.cells.enumerated() {
            let validOptions = cell.validOptions
            self.cells[index].simplePencilMarks = validOptions
            self.cells[index].advancedPencilMarks = cell.advancedPencilMarks.intersection(
                validOptions)
            self.cells[index].ruledOutCandidates = cell.ruledOutCandidates.intersection(
                validOptions)
        }
    }

    public func eliminatePencilMarks() {
        for (index, cell) in self.cells.enumerated() {
            let validOptions = cell.validOptions
            self.cells[index].simplePencilMarks = cell.simplePencilMarks.intersection(validOptions)
            self.cells[index].advancedPencilMarks = cell.advancedPencilMarks.intersection(
                validOptions)
            self.cells[index].ruledOutCandidates = cell.ruledOutCandidates.intersection(
                validOptions)
        }
    }

    internal func updateCompletedSets() {
        updateCompletedSets(grid: currentGrid)
    }

    internal func updateCompletedSets(grid: [[Int]]) {

        // check the current state against the know solution
        if grid == solution {
            isSolved = true
        } else if let solution, solution.count == 9 {
            var matchesSolution = true
            for (row, columns) in grid.enumerated() {
                for (col, value) in columns.enumerated() {
                    if value != 0 && solution[row][col] != value {
                        matchesSolution = false
                    }
                }
            }
            isSolvable = matchesSolution
            if isSolvable == false {
                incorrectMoves += 1
            }
        }

        var completedRows: Set<Int> = []
        var completedColumns: Set<Int> = []
        var completedHouses: Set<Int> = []
        var completedNumbers: Set<Int> = []

        // We want to gather digits from each row, col, box, and digit usage
        // rowSets[i] => set of digits in row i
        // colSets[j] => set of digits in column j
        // boxSets[b] => set of digits in box b
        // digitCount[d] => number of times digit d appears on the board

        var rowSets = Array(repeating: Set<Int>(), count: 9)
        var colSets = Array(repeating: Set<Int>(), count: 9)
        var boxSets = Array(repeating: Set<Int>(), count: 9)
        var digitCount = Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 0) })

        for cell in cells {
            guard let value = cell.value else {
                continue
            }

            let r = cell.position.row
            let c = cell.position.column
            rowSets[r].insert(value)
            colSets[c].insert(value)

            // Identify the 3×3 box index: row/3*3 + col/3
            let boxIndex = (r / 3) * 3 + (c / 3)
            boxSets[boxIndex].insert(value)

            // Tally usage for the digit
            digitCount[value, default: 0] += 1
        }

        let allDigits = Set(1...9)

        for r in 0..<9 {
            if rowSets[r].count == 9 && rowSets[r] == allDigits {
                completedRows.insert(r)
            }
        }

        for c in 0..<9 {
            if colSets[c].count == 9 && colSets[c] == allDigits {
                completedColumns.insert(c)
            }
        }

        for b in 0..<9 {
            if boxSets[b].count == 9 && boxSets[b] == allDigits {
                completedHouses.insert(b)
            }
        }

        for d in 1...9 {
            if digitCount[d] == 9 {
                completedNumbers.insert(d)
            }
        }

        self.completedRows = completedRows
        self.completedColumns = completedColumns
        self.completedHouses = completedHouses
        self.completedNumbers = completedNumbers

        if (try? Validator.isCompleteAndValidSolution(grid)) == true,
            constraintViolations.isEmpty
        {
            self.isSolved = true
        } else {
            self.isSolved = false
        }
    }
}
