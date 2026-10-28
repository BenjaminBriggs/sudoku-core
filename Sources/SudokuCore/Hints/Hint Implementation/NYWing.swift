//
//  NYWing.swift
//  SudokuCore
//
//  Created by Claude on 27/10/2026.
//
import Foundation

// MARK: - n-Y-Wing Technique (4-Y-Wing / WXYZ-Wing and larger)
extension HintFinder {
    /// Finds an n-Y-Wing: a pivot group of cells in one unit plus wing cells that each see
    /// every pivot, `n` cells holding just `n` digits between them.
    ///
    /// Every digit but one, z, is restricted: all of its copies in the group see each other, so
    /// it can fill at most one of the cells. Without z the `n` cells would need `n` values from
    /// `n - 1` digits used once each, which is impossible, so one of them is z. Any cell that
    /// sees every copy of z in the group loses it.
    ///
    /// Sudoku Coach's definition (two wing groups sharing only z) relies on each wing's cells
    /// seeing each other. Checking that every digit but z is restricted is what makes it
    /// sound, and it accepts every shape that definition does once that holds.
    ///
    /// - Parameters:
    ///   - n: The number of cells and digits (4 to 7).
    ///   - technique: The `TechniqueInfo` to tag the result with.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` for the first n-Y-Wing found, or `nil`.
    static func findNYWing(size n: Int, technique: TechniqueInfo, in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Candidate bitmasks (bit d set for digit d) for empty cells with two or more notes.
        // Solved and single-candidate cells can't take part, so they stay 0.
        var masks = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for row in 0..<9 {
            for column in 0..<9 where grid[row][column] == 0 && pencilMarks[row][column].count >= 2 {
                masks[row][column] = pencilMarks[row][column].reduce(0) { $0 | (1 << $1) }
            }
        }
        let mask = { (cell: Puzzle.Index) in masks[cell.row][cell.column] }
        let sees = { (a: Puzzle.Index, b: Puzzle.Index) in LookupTables.cellNeighbours[a.row][a.column].contains(b) }

        // Builds the hint for a full group whose only unrestricted digit is z, if it eliminates.
        func evaluate(unit: SudokuUnit, pivots: [Puzzle.Index], wings: [Puzzle.Index], z: Int) -> HintStep? {
            let cells = pivots + wings
            let zCells = cells.filter { mask($0) & (1 << z) != 0 }
            var targets = LookupTables.cellNeighbours[zCells[0].row][zCells[0].column]
            for cell in zCells.dropFirst() {
                targets.formIntersection(LookupTables.cellNeighbours[cell.row][cell.column])
            }
            let eliminationCells = targets.filter { position in
                cells.contains(position) == false
                    && grid[position.row][position.column] == 0
                    && pencilMarks[position.row][position.column].contains(z)
            }
            guard eliminationCells.isEmpty == false else { return nil }

            let removals = eliminationCells.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
                .map { HintAction(position: $0, ruleOut: z) }
            return HintStep(
                actions: removals,
                technique: technique,
                reasoning: HintReasoning(
                    actions: removals,
                    focusDigits: [z],
                    units: [unit],
                    components: [
                        .pivot(pivots, in: state, unit: unit),
                        .wing(wings, in: state),
                        .eliminated(eliminationCells, candidates: [z])
                    ]
                )
            )
        }

        for unit in SudokuUnit.allUnits {
            let unitCells = unit.positions.filter { mask($0) != 0 }
            for pivotCount in 1...(n - 2) {
                for pivots in combinations(of: unitCells, choose: pivotCount) {
                    let pivotUnion = pivots.reduce(0) { $0 | mask($1) }
                    guard pivotUnion.nonzeroBitCount <= n else { continue }

                    // Wing cells see every pivot.
                    var common = LookupTables.cellNeighbours[pivots[0].row][pivots[0].column]
                    for pivot in pivots.dropFirst() {
                        common.formIntersection(LookupTables.cellNeighbours[pivot.row][pivot.column])
                    }
                    let pool = common
                        .filter { mask($0) != 0 && pivots.contains($0) == false }
                        .sorted { ($0.row, $0.column) < ($1.row, $1.column) }
                    let needed = n - pivotCount
                    guard pool.count >= needed else { continue }
                    // A group inside one unit has every digit restricted, so it never has a z.
                    // Pivots that share a unit but not a box-line segment leave wings only there.
                    let group = pivots + pool
                    if SudokuUnit.allUnits.contains(where: { unit in group.allSatisfy(unit.positions.contains) }) { continue }

                    // Pivots share a unit, so they start with every digit restricted.
                    var holders = Array(repeating: [Puzzle.Index](), count: 10)
                    for pivot in pivots {
                        for digit in 1...9 where mask(pivot) & (1 << digit) != 0 { holders[digit].append(pivot) }
                    }

                    // Depth-first over wing cells. Adding cells only grows the digits and can only
                    // unrestrict them, so a branch past n digits or with two unrestricted is dead.
                    var wings: [Puzzle.Index] = []
                    func extend(from start: Int, union: Int, unrestricted: Int) -> HintStep? {
                        if wings.count == needed {
                            guard union.nonzeroBitCount == n, unrestricted.nonzeroBitCount == 1 else { return nil }
                            return evaluate(unit: unit, pivots: pivots, wings: wings, z: unrestricted.trailingZeroBitCount)
                        }
                        guard pool.count - start >= needed - wings.count else { return nil }
                        for i in start..<pool.count {
                            let cell = pool[i]
                            let cellMask = mask(cell)
                            let next = union | cellMask
                            guard next.nonzeroBitCount <= n else { continue }
                            var nextUnrestricted = unrestricted
                            for digit in 1...9 where cellMask & (1 << digit) != 0 && nextUnrestricted & (1 << digit) == 0 {
                                if holders[digit].contains(where: { sees(cell, $0) == false }) {
                                    nextUnrestricted |= 1 << digit
                                }
                            }
                            guard nextUnrestricted.nonzeroBitCount <= 1 else { continue }

                            for digit in 1...9 where cellMask & (1 << digit) != 0 { holders[digit].append(cell) }
                            wings.append(cell)
                            if let hint = extend(from: i + 1, union: next, unrestricted: nextUnrestricted) { return hint }
                            wings.removeLast()
                            for digit in 1...9 where cellMask & (1 << digit) != 0 { holders[digit].removeLast() }
                        }
                        return nil
                    }
                    if let hint = extend(from: 0, union: pivotUnion, unrestricted: 0) { return hint }
                }
            }
        }

        return nil
    }
}
