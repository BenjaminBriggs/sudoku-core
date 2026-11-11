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
        let peers = LookupTables.peerMasks

        // Candidate bitmasks (bit d set for digit d) for empty cells with two or more notes,
        // by cell index (`row * 9 + column`). Solved and single-candidate cells can't take
        // part, so they stay 0 and out of `eligible`.
        var masks = [Int](repeating: 0, count: 81)
        var eligible: UInt128 = 0
        for row in 0..<9 {
            for column in 0..<9 where grid[row][column] == 0 && pencilMarks[row][column].count >= 2 {
                masks[row * 9 + column] = pencilMarks[row][column].reduce(0) { $0 | (1 << $1) }
                eligible |= LookupTables.cellBit(row * 9 + column)
            }
        }
        let position = { (cell: Int) in Puzzle.Index(row: cell / 9, column: cell % 9) }

        // Builds the hint for a full group whose only unrestricted digit is z, if it eliminates.
        func evaluate(unit: SudokuUnit, pivots: [Int], wings: [Int], z: Int) -> HintStep? {
            // Cells that see every copy of z in the group, and aren't in it
            var targets = LookupTables.allCellsMask
            for cell in pivots + wings {
                targets &= ~LookupTables.cellBit(cell)
                if masks[cell] & (1 << z) != 0 { targets &= peers[cell] }
            }
            // Ascending cell index, which is row then column
            var eliminationCells: [Puzzle.Index] = []
            while targets != 0 {
                let cell = targets.trailingZeroBitCount
                targets &= targets - 1
                if grid[cell / 9][cell % 9] == 0, pencilMarks[cell / 9][cell % 9].contains(z) {
                    eliminationCells.append(position(cell))
                }
            }
            guard eliminationCells.isEmpty == false else { return nil }

            let removals = eliminationCells.map { HintAction(position: $0, ruleOut: z) }
            return HintStep(
                actions: removals,
                technique: technique,
                reasoning: HintReasoning(
                    actions: removals,
                    focusDigits: [z],
                    units: [unit],
                    components: [
                        .pivot(pivots.map(position), in: state, unit: unit),
                        .wing(wings.map(position), in: state),
                        .eliminated(eliminationCells, candidates: [z])
                    ]
                )
            )
        }

        var search = NYWingSearch(n: n, masks: masks, peers: peers)
        for unit in SudokuUnit.allUnits {
            let unitCells = unit.positions.map { $0.row * 9 + $0.column }.filter { masks[$0] != 0 }
            for pivotCount in 1...(n - 2) {
                for choice in LookupTables.choices(of: unitCells.count, choose: pivotCount) {
                    var pivotUnion = 0
                    var pivotCells: UInt128 = 0
                    // Wing cells see every pivot.
                    var common = LookupTables.allCellsMask
                    for index in choice {
                        let pivot = unitCells[index]
                        pivotUnion |= masks[pivot]
                        pivotCells |= LookupTables.cellBit(pivot)
                        common &= peers[pivot]
                    }
                    guard pivotUnion.nonzeroBitCount <= n else { continue }

                    let poolCells = common & eligible
                    let needed = n - pivotCount
                    guard poolCells.nonzeroBitCount >= needed else { continue }
                    // A group inside one unit has every digit restricted, so it never has a z.
                    // Pivots that share a unit but not a box-line segment leave wings only there.
                    let group = pivotCells | poolCells
                    if LookupTables.unitMasks.contains(where: { $0 & group == group }) { continue }

                    search.start(pivots: pivotCells, pool: poolCells, pivotUnion: pivotUnion, needed: needed)
                    let hint = search.extend(from: 0, union: pivotUnion, unrestricted: 0) { wings, z in
                        evaluate(unit: unit, pivots: choice.map { unitCells[$0] }, wings: wings, z: z)
                    }
                    if let hint { return hint }
                }
            }
        }

        return nil
    }
}

/// The depth-first search over wing cells for one choice of pivots. Kept in a struct, and
/// reused from one choice of pivots to the next, so the search allocates nothing as it goes:
/// it runs at every state every other technique fails at.
private struct NYWingSearch {
    /// The number of cells and digits.
    let n: Int
    /// Candidate bitmasks (bit d set for digit d) by cell index; 0 for cells that can't take part.
    let masks: [Int]
    let peers: [UInt128]

    /// The wing cells still to find.
    private var needed = 0
    /// Cells that see every pivot and could join without taking the group past `n` digits, in
    /// ascending cell index, which is row then column.
    private var pool: [Int] = []
    /// The group's cells holding each digit.
    private var holders = [UInt128](repeating: 0, count: 10)
    private var wings: [Int] = []

    init(n: Int, masks: [Int], peers: [UInt128]) {
        self.n = n
        self.masks = masks
        self.peers = peers
    }

    /// Sets the search up for a choice of pivots.
    mutating func start(pivots: UInt128, pool poolCells: UInt128, pivotUnion: Int, needed: Int) {
        self.needed = needed
        wings.removeAll(keepingCapacity: true)

        // A cell that takes the pivots' digits past n on its own can never join
        pool.removeAll(keepingCapacity: true)
        var remaining = poolCells
        while remaining != 0 {
            let cell = remaining.trailingZeroBitCount
            remaining &= remaining - 1
            if (pivotUnion | masks[cell]).nonzeroBitCount <= n { pool.append(cell) }
        }

        // Pivots share a unit, so they start with every digit restricted.
        for digit in 1...9 { holders[digit] = 0 }
        var remainingPivots = pivots
        while remainingPivots != 0 {
            let pivot = remainingPivots.trailingZeroBitCount
            remainingPivots &= remainingPivots - 1
            var digits = masks[pivot]
            while digits != 0 {
                holders[digits.trailingZeroBitCount] |= LookupTables.cellBit(pivot)
                digits &= digits - 1
            }
        }
    }

    /// Depth-first over wing cells from `pool[start]`. Adding cells only grows the digits and
    /// can only unrestrict them, so a branch past n digits or with two unrestricted is dead.
    ///
    /// - Parameter accept: Given a full group's wings and its one unrestricted digit, returns
    ///   the hint if the group eliminates anything.
    mutating func extend(
        from start: Int, union: Int, unrestricted: Int,
        accept: (_ wings: [Int], _ z: Int) -> HintStep?
    ) -> HintStep? {
        if wings.count == needed {
            guard union.nonzeroBitCount == n, unrestricted.nonzeroBitCount == 1 else { return nil }
            return accept(wings, unrestricted.trailingZeroBitCount)
        }
        guard pool.count - start >= needed - wings.count else { return nil }
        for i in start..<pool.count {
            let cell = pool[i]
            let cellMask = masks[cell]
            let next = union | cellMask
            guard next.nonzeroBitCount <= n else { continue }
            // A digit stops being restricted once a cell holding it doesn't see this one
            var nextUnrestricted = unrestricted
            let unseen = ~peers[cell]
            var digits = cellMask
            while digits != 0 {
                let digit = digits.trailingZeroBitCount
                digits &= digits - 1
                if holders[digit] & unseen != 0 { nextUnrestricted |= 1 << digit }
            }
            guard nextUnrestricted.nonzeroBitCount <= 1 else { continue }

            let bit = LookupTables.cellBit(cell)
            digits = cellMask
            while digits != 0 {
                holders[digits.trailingZeroBitCount] |= bit
                digits &= digits - 1
            }
            wings.append(cell)
            if let hint = extend(from: i + 1, union: next, unrestricted: nextUnrestricted, accept: accept) {
                return hint
            }
            wings.removeLast()
            digits = cellMask
            while digits != 0 {
                holders[digits.trailingZeroBitCount] &= ~bit
                digits &= digits - 1
            }
        }
        return nil
    }
}
