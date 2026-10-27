//
//  UniqueRectangles.swift
//  SudokuCore
//
//  Created by Claude on 27/10/2026.
//
import Foundation

// MARK: - Unique Rectangle Techniques
extension HintFinder {
    /// Finds a Unique Rectangle of the given type.
    ///
    /// Four empty cells at the corners of a rectangle spanning two boxes that held only the
    /// same two candidates {a, b} would be a deadly pattern: the a's and b's could swap, so the
    /// puzzle would have two solutions. A puzzle with one solution can't contain one, so one of
    /// the corners must hold something other than a or b.
    ///
    /// - Type 1: three corners are exactly {a, b}, so the fourth isn't a or b.
    /// - Type 2: two corners on one side are exactly {a, b} and the other two each add the same
    ///   single digit x. One of those two is x, so cells seeing both lose x.
    /// - Type 3: two corners on one side are exactly {a, b}. The other two corners' extra digits
    ///   act as one cell that forms a naked subset with other cells of a unit the two share.
    /// - Type 4: two corners on one side are exactly {a, b}, and in a unit the other two share,
    ///   a can only go in those two. One of them is a, so neither can be b.
    /// - Type 5: two diagonal corners, or three corners, add the same single digit x. One of
    ///   them is x, so cells seeing all of them lose x.
    ///
    /// Only runs when the board is known to have exactly one solution.
    ///
    /// - Parameters:
    ///   - type: The Unique Rectangle type, 1 to 5.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` for the first rectangle of that type found, or `nil`.
    static func findUniqueRectangle(type: Int, in state: BoardState) -> HintStep? {
        guard state.assumesUniqueSolution else { return nil }
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for r1 in 0..<8 {
            for r2 in (r1 + 1)..<9 {
                for c1 in 0..<8 {
                    for c2 in (c1 + 1)..<9 {
                        // Exactly two boxes: the rows share a band or the columns share a stack, not both.
                        guard (r1 / 3 == r2 / 3) != (c1 / 3 == c2 / 3) else { continue }
                        let corners = [
                            Puzzle.Index(row: r1, column: c1), Puzzle.Index(row: r1, column: c2),
                            Puzzle.Index(row: r2, column: c1), Puzzle.Index(row: r2, column: c2)
                        ]
                        guard corners.allSatisfy({ grid[$0.row][$0.column] == 0 }) else { continue }
                        let common = corners.dropFirst().reduce(pencilMarks[r1][c1]) {
                            $0.intersection(pencilMarks[$1.row][$1.column])
                        }
                        guard common.count >= 2 else { continue }

                        for pair in combinations(of: common.sorted(), choose: 2) {
                            if let hint = uniqueRectangle(type: type, corners: corners, pair: Set(pair), in: state) {
                                return hint
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Checks one rectangle and candidate pair for the given type.
    private static func uniqueRectangle(
        type: Int,
        corners: [Puzzle.Index],
        pair: Set<Int>,
        in state: BoardState
    ) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks
        let candidates = { (cell: Puzzle.Index) in pencilMarks[cell.row][cell.column] }
        let exact = corners.filter { candidates($0) == pair }
        let extra = corners.filter { candidates($0) != pair }
        let pairDigits = pair.sorted()

        // The other cells that see every one of `cells` and still hold `digit`.
        func commonPeers(of cells: [Puzzle.Index], holding digit: Int) -> Set<Puzzle.Index> {
            var seen = LookupTables.cellNeighbours[cells[0].row][cells[0].column]
            for cell in cells.dropFirst() {
                seen.formIntersection(LookupTables.cellNeighbours[cell.row][cell.column])
            }
            return seen.filter {
                corners.contains($0) == false && grid[$0.row][$0.column] == 0 && candidates($0).contains(digit)
            }
        }

        // The one digit each of `cells` adds to the pair, if they all add the same single digit.
        func sharedExtraDigit(_ cells: [Puzzle.Index]) -> Int? {
            let extras = Set(cells.map { candidates($0).subtracting(pair) })
            guard extras.count == 1, let only = extras.first, only.count == 1 else { return nil }
            return only.first
        }

        // Builds a hint, ordering removals so output is deterministic.
        func hint(
            _ technique: HintTechnique,
            focus: [Int],
            removals: [(Puzzle.Index, Int)],
            units: [SudokuUnit] = [],
            extraComponents: [HintComponent] = []
        ) -> HintStep? {
            guard removals.isEmpty == false else { return nil }
            let actions = removals
                .sorted { ($0.0.row, $0.0.column, $0.1) < ($1.0.row, $1.0.column, $1.1) }
                .map { HintAction(position: $0.0, ruleOut: $0.1) }
            return HintStep(
                actions: actions,
                technique: technique,
                reasoning: HintReasoning(
                    actions: actions,
                    focusDigits: focus,
                    units: units,
                    components: [
                        .base(corners, in: state),
                        .fin(extra, in: state)
                    ] + extraComponents + [
                        .eliminated(Set(removals.map(\.0)), in: state)
                    ]
                )
            )
        }

        // Types 2 to 4 need the two exact corners on one side of the rectangle.
        let floorIsSide = exact.count == 2
            && (exact[0].row == exact[1].row || exact[0].column == exact[1].column)
        // Units both extra corners belong to (their row or column, plus a box if they share one).
        let sharedUnits: [SudokuUnit] = extra.count == 2 ? SudokuUnit.allUnits.filter { unit in
            let positions = unit.positions
            return positions.contains(extra[0]) && positions.contains(extra[1])
        } : []

        switch type {
        case 1:
            guard exact.count == 3, let corner = extra.first else { return nil }
            return hint(
                .uniqueRectangleType1,
                focus: pairDigits,
                removals: pairDigits.map { (corner, $0) }
            )

        case 2:
            guard floorIsSide, let x = sharedExtraDigit(extra) else { return nil }
            return hint(
                .uniqueRectangleType2,
                focus: pairDigits + [x],
                removals: commonPeers(of: extra, holding: x).map { ($0, x) }
            )

        case 3:
            guard floorIsSide else { return nil }
            let virtualDigits = candidates(extra[0]).union(candidates(extra[1])).subtracting(pair)
            for unit in sharedUnits {
                let others = unit.positions.filter {
                    extra.contains($0) == false && grid[$0.row][$0.column] == 0
                }
                // Any number of other cells, as HoDoKu searches, leaving at least one to clear.
                for size in 1..<max(2, others.count) {
                    for subset in combinations(of: others, choose: size) {
                        let digits = subset.reduce(virtualDigits) { $0.union(candidates($1)) }
                        guard digits.count == size + 1 else { continue }
                        let removals = others
                            .filter { subset.contains($0) == false }
                            .flatMap { cell in candidates(cell).intersection(digits).map { (cell, $0) } }
                        if let found = hint(
                            .uniqueRectangleType3,
                            focus: pairDigits + digits.sorted(),
                            removals: removals,
                            units: [unit],
                            extraComponents: [.subset(subset, in: state, unit: unit)]
                        ) {
                            return found
                        }
                    }
                }
            }
            return nil

        case 4:
            guard floorIsSide else { return nil }
            for unit in sharedUnits {
                for (locked, other) in [(pairDigits[0], pairDigits[1]), (pairDigits[1], pairDigits[0])] {
                    let homes = unit.positions.filter {
                        grid[$0.row][$0.column] == 0 && candidates($0).contains(locked)
                    }
                    guard Set(homes) == Set(extra) else { continue }
                    if let found = hint(
                        .uniqueRectangleType4,
                        focus: [locked, other],
                        removals: extra.map { ($0, other) },
                        units: [unit]
                    ) {
                        return found
                    }
                }
            }
            return nil

        case 5:
            let isDiagonal = extra.count == 2
                && extra[0].row != extra[1].row && extra[0].column != extra[1].column
            guard isDiagonal || extra.count == 3, let x = sharedExtraDigit(extra) else { return nil }
            return hint(
                .uniqueRectangleType5,
                focus: pairDigits + [x],
                removals: commonPeers(of: extra, holding: x).map { ($0, x) }
            )

        default:
            return nil
        }
    }
}
