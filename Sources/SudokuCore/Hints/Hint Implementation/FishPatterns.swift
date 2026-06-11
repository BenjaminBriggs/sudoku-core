//
//  FishPatterns.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation
import Collections

// MARK: - Fish Pattern Technique (Generic for X-Wing, Swordfish, Jellyfish)
extension HintFinder {
    /// Maps the fish size `n` and finned status to the corresponding `TechniqueInfo`.
    /// - Parameters:
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - includesFin: Whether the pattern has fin candidates.
    /// - Returns: The matching `TechniqueInfo` enum case.
    private static func fishTechnique(for n: Int, includesFin: Bool) -> TechniqueInfo {
        if includesFin {
            switch n {
            case 2: return .finnedXWing
            case 3: return .finnedSwordfish
            case 4: return .finnedJellyfish
            default: fatalError("Unhandled finned fish pattern size")
            }
        } else {
            switch n {
            case 2: return .xWing
            case 3: return .swordfish
            case 4: return .jellyfish
            default: fatalError("Unhandled fish pattern size")
            }
        }
    }

    // MARK: - Fin Detection Helpers

    /// Detects fins in a fish pattern for either orientation.
    ///
    /// Fins are extra candidate positions that spill beyond the `n` core cross lines.
    /// The algorithm ranks cross lines by how many base lines they appear in, selects
    /// the top `n` as core lines, and treats remaining positions as fins.
    /// When counts are ambiguous (multiple cross lines share the same frequency),
    /// all `n`-element combinations are tried until a valid partition is found.
    ///
    /// - Parameters:
    ///   - digit: The candidate digit being analysed.
    ///   - fishBaseLines: The set of base-line indices forming the fish.
    ///   - allCrossLines: The union of cross-line indices across all base lines.
    ///   - baseLineToCrossLines: A mapping from each base line to the cross lines where the digit appears.
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - baseOrientation: Whether base lines are rows or columns.
    ///   - state: The current board state snapshot.
    /// - Returns: A tuple of the `n` core cross lines and the set of fin cell positions,
    ///   or `nil` if no valid finned partition exists.
    private static func detectFins(
        digit: Int,
        fishBaseLines: Set<Int>,
        allCrossLines: Set<Int>,
        baseLineToCrossLines: [Int: Set<Int>],
        n: Int,
        baseOrientation: Puzzle.Index.Orientation,
        state: BoardState
    ) -> (coreCrossLines: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Orientation abstraction: `makeIndex` converts (baseLine, crossLine) into
        // a Puzzle.Index regardless of whether base lines are rows or columns.
        let makeIndex: (Int, Int) -> Puzzle.Index = baseOrientation == .row
            ? { base, cross in Puzzle.Index(row: base, column: cross) }
            : { base, cross in Puzzle.Index(row: cross, column: base) }

        // Count how many base lines each cross line appears in
        var crossLineCounts: [Int: Int] = [:]
        for crossLine in allCrossLines {
            var count = 0
            for baseLine in fishBaseLines {
                if baseLineToCrossLines[baseLine]?.contains(crossLine) == true {
                    count += 1
                }
            }
            crossLineCounts[crossLine] = count
        }

        // Core cross lines appear in the most base lines; fin cross lines appear in fewer.
        // Sort descending by frequency so the first n entries are the best core candidates.
        // Ties are broken by ascending index for deterministic output.
        let sortedCrossLines = allCrossLines.sorted {
            if crossLineCounts[$0]! != crossLineCounts[$1]! {
                return crossLineCounts[$0]! > crossLineCounts[$1]!
            }
            return $0 < $1
        }

        // Try different combinations when counts are equal
        guard sortedCrossLines.count >= n else { return nil }

        // If cross lines have clearly different counts, use the standard approach
        let maxCount = crossLineCounts[sortedCrossLines[0]]!
        let nthCount = crossLineCounts[sortedCrossLines[min(n-1, sortedCrossLines.count-1)]]!

        if maxCount > nthCount || sortedCrossLines.count == n {
            // Standard case: clear distinction OR exact fit
            let coreCrossLines = Set(sortedCrossLines.prefix(n))
            let finCrossLines = allCrossLines.subtracting(coreCrossLines)

            if let result = validateFins(
                digit: digit,
                fishBaseLines: fishBaseLines,
                coreCrossLines: coreCrossLines,
                finCrossLines: finCrossLines,
                baseLineToCrossLines: baseLineToCrossLines,
                makeIndex: makeIndex,
                state: state
            ) {
                return result
            }
        } else {
            // Ambiguous case: try all combinations of n cross lines
            let crossLinesArray = Array(sortedCrossLines)
            for combo in combinations(of: crossLinesArray, choose: n) {
                let coreCrossLines = Set(combo)
                let finCrossLines = allCrossLines.subtracting(coreCrossLines)

                if let result = validateFins(
                    digit: digit,
                    fishBaseLines: fishBaseLines,
                    coreCrossLines: coreCrossLines,
                    finCrossLines: finCrossLines,
                    baseLineToCrossLines: baseLineToCrossLines,
                    makeIndex: makeIndex,
                    state: state
                ) {
                    return result
                }
            }
        }

        return nil
    }

    /// Validates a proposed core/fin partition for a fish pattern.
    ///
    /// A partition is valid when:
    /// 1. At least one fin cell exists in the fin cross lines.
    /// 2. All fins reside in the **same 3x3 box** (the same-box constraint).
    /// 3. At least one elimination exists: a candidate in a core cross line, outside the
    ///    fish base lines, whose cell **sees every fin** (shares a row, column, or box).
    ///
    /// - Parameters:
    ///   - digit: The candidate digit being analysed.
    ///   - fishBaseLines: The set of base-line indices forming the fish.
    ///   - coreCrossLines: The proposed core cross-line indices.
    ///   - finCrossLines: The cross-line indices that fall outside the core set.
    ///   - baseLineToCrossLines: A mapping from each base line to the cross lines where the digit appears.
    ///   - makeIndex: A closure that converts (baseLine, crossLine) into a `Puzzle.Index`.
    ///   - state: The current board state snapshot.
    /// - Returns: The validated `(coreCrossLines, fins)` tuple, or `nil` if invalid.
    private static func validateFins(
        digit: Int,
        fishBaseLines: Set<Int>,
        coreCrossLines: Set<Int>,
        finCrossLines: Set<Int>,
        baseLineToCrossLines: [Int: Set<Int>],
        makeIndex: (Int, Int) -> Puzzle.Index,
        state: BoardState
    ) -> (coreCrossLines: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Collect fin positions: cells at the intersection of base lines and fin cross lines
        // that still hold the digit as a pencil mark.
        var fins = Set<Puzzle.Index>()
        for baseLine in fishBaseLines {
            guard let crossLines = baseLineToCrossLines[baseLine] else { continue }
            for crossLine in finCrossLines {
                if crossLines.contains(crossLine) {
                    let position = makeIndex(baseLine, crossLine)
                    if state.pencilMarks[position.row][position.column].contains(digit) {
                        fins.insert(position)
                    }
                }
            }
        }

        // Must have at least one fin
        guard fins.isEmpty == false else {
            return nil
        }

        // Same-box constraint: all fins must share one 3x3 box so that
        // eliminations can be confined to cells that see the entire fin group.
        guard let firstFin = fins.first else { return nil }
        let finBox = (firstFin.row / 3, firstFin.column / 3)
        for fin in fins {
            let box = (fin.row / 3, fin.column / 3)
            if box != finBox {
                return nil
            }
        }

        // Elimination verification: scan core cross lines outside the fish base lines.
        // A candidate is only eliminable if the cell sees every fin (i.e. shares a
        // constraining unit with all fin positions). At least one such elimination must
        // exist for the partition to be useful.
        var hasEliminations = false
        for crossLine in coreCrossLines {
            for baseLine in 0..<9 where fishBaseLines.contains(baseLine) == false {
                let position = makeIndex(baseLine, crossLine)
                if state.grid[position.row][position.column] == 0 {
                    let candidates = state.pencilMarks[position.row][position.column]
                    if candidates.contains(digit) {
                        let cellNeighbours = Self.getConstrainingCells(for: position)
                        if fins.allSatisfy({ cellNeighbours.contains($0) }) {
                            hasEliminations = true
                            break
                        }
                    }
                }
            }
            if hasEliminations { break }
        }

        guard hasEliminations else { return nil }

        return (coreCrossLines, fins)
    }

    // MARK: - Main Fish Finding

    /// Searches for a fish pattern of size `n` in both row-based and column-based orientations.
    ///
    /// A fish pattern occurs when a digit's candidates in `n` base lines are confined to
    /// exactly `n` cross lines, allowing eliminations in those cross lines outside the base lines.
    ///
    /// - Parameters:
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - requiresFin: When `true`, only finned variants are returned.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` describing the pattern and its eliminations, or `nil` if none found.
    static func findNFish(n: Int, requiresFin: Bool = false, in state: BoardState) -> HintStep? {
        if let hint = findNFishInOrientation(n: n, requiresFin: requiresFin, baseOrientation: .row, state: state) {
            return hint
        }
        if let hint = findNFishInOrientation(n: n, requiresFin: requiresFin, baseOrientation: .column, state: state) {
            return hint
        }
        return nil
    }

    /// Searches for a fish pattern in a single orientation (row-based or column-based).
    ///
    /// The algorithm iterates over each digit 1-9, builds a map of base lines to the
    /// cross lines where the digit appears, then checks every `n`-combination of base
    /// lines. A perfect fish has exactly `n` cross lines; a finned fish has `n+1` or
    /// `n+2` cross lines with valid fins.
    ///
    /// - Parameters:
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - requiresFin: When `true`, only finned variants are returned.
    ///   - baseOrientation: Whether base lines are rows or columns.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` for the first valid fish found, or `nil`.
    private static func findNFishInOrientation(
        n: Int,
        requiresFin: Bool,
        baseOrientation: Puzzle.Index.Orientation,
        state: BoardState
    ) -> HintStep? {
        // Orientation abstraction closures:
        // `makeIndex` maps (baseLine, crossLine) -> Puzzle.Index for either orientation.
        // `getBase` extracts the base-line index from a Puzzle.Index.
        let makeIndex: (Int, Int) -> Puzzle.Index = baseOrientation == .row
            ? { base, cross in Puzzle.Index(row: base, column: cross) }
            : { base, cross in Puzzle.Index(row: cross, column: base) }

        let getBase: (Puzzle.Index) -> Int = baseOrientation == .row
            ? { $0.row }
            : { $0.column }

        // Pre-compute pencil marks for all cells to avoid repeated lookups
        let pencilMarks = state.pencilMarks

        // For each digit
        for digit in 1...9 {
            // Build a map of base lines -> cross lines where digit appears as a candidate
            var baseLineToCrossLines: [Int: Set<Int>] = [:]
            baseLineToCrossLines.reserveCapacity(9)

            for baseLine in 0..<9 {
                var candidateCrossLines = Set<Int>()
                candidateCrossLines.reserveCapacity(9)

                for crossLine in 0..<9 {
                    let position = makeIndex(baseLine, crossLine)
                    if state.grid[position.row][position.column] == 0 {
                        if pencilMarks[position.row][position.column].contains(digit) {
                            candidateCrossLines.insert(crossLine)
                        }
                    }
                }

                // Include base lines with 2+ candidate positions
                if candidateCrossLines.count >= 2 {
                    baseLineToCrossLines[baseLine] = candidateCrossLines
                }
            }

            // Need at least 2 base lines with candidates
            if baseLineToCrossLines.count < 2 {
                continue
            }

            // Check all combinations of n base lines (sorted for determinism)
            let baseLines = Array(baseLineToCrossLines.keys).sorted()
            for combo in combinations(of: baseLines, choose: n) {
                let fishBaseLines = Set(combo)

                // Get union of all cross lines
                var allCrossLines = Set<Int>()
                for baseLine in fishBaseLines {
                    if let crossLines = baseLineToCrossLines[baseLine] {
                        allCrossLines.formUnion(crossLines)
                    }
                }

                // Check for perfect fish or finned fish
                var coreCrossLines = allCrossLines
                var fins = Set<Puzzle.Index>()
                var includesFin = false

                if allCrossLines.count == n {
                    // Perfect fish
                    if requiresFin {
                        continue // Skip perfect fish when requiring fins
                    }
                    // Process as regular fish
                } else if allCrossLines.count > n && allCrossLines.count <= n + 2 {
                    // Potential finned fish
                    if requiresFin {
                        // Try to detect fins
                        if let finData = detectFins(
                            digit: digit,
                            fishBaseLines: fishBaseLines,
                            allCrossLines: allCrossLines,
                            baseLineToCrossLines: baseLineToCrossLines,
                            n: n,
                            baseOrientation: baseOrientation,
                            state: state
                        ) {
                            coreCrossLines = finData.coreCrossLines
                            fins = finData.fins
                            includesFin = true
                        } else {
                            continue // Not a valid finned fish
                        }
                    } else {
                        continue // Skip finned patterns when not requiring fins
                    }
                } else {
                    continue // Too many cross lines or not enough
                }

                // Create matrix of positions where the digit appears
                var fishPositions = Set<Puzzle.Index>()
                for baseLine in fishBaseLines {
                    for crossLine in coreCrossLines {
                        let position = makeIndex(baseLine, crossLine)
                        if state.grid[position.row][position.column] == 0 &&
                            state.pencilMarks[position.row][position.column].contains(digit) {
                            fishPositions.insert(position)
                        }
                    }
                }
                // Include fins in fish positions for visualization
                fishPositions.formUnion(fins)

                // Validation
                if fishPositions.count < 2 {
                    continue
                }

                // Ensure at least 2 of the n base lines contain the digit
                let baseLinesWithPositions = Set(fishPositions.map { getBase($0) })
                if baseLinesWithPositions.count < 2 {
                    continue
                }

                // Check if we can eliminate digit from other cells
                var removals: [HintAction] = []
                var eliminationCells = Set<Puzzle.Index>()

                for crossLine in coreCrossLines {
                    for baseLine in 0..<9 where fishBaseLines.contains(baseLine) == false {
                        let position = makeIndex(baseLine, crossLine)
                        if state.grid[position.row][position.column] == 0 {
                            let candidates = state.pencilMarks[position.row][position.column]
                            if candidates.contains(digit) {
                                // For finned fish, only eliminate if cell sees all fins
                                if includesFin {
                                    let cellNeighbours = Self.getConstrainingCells(for: position)
                                    if fins.allSatisfy({ cellNeighbours.contains($0) }) == false {
                                        continue // Cell doesn't see all fins
                                    }
                                }
                                removals.append(HintAction(position: position, ruleOut: digit))
                                eliminationCells.insert(position)
                            }
                        }
                    }
                }

                if removals.isEmpty == false {
                    let technique = fishTechnique(
                        for: n,
                        includesFin: includesFin
                    )
                    let crossOrientation: Puzzle.Index.Orientation = baseOrientation == .row ? .column : .row
                    let fishUnits = fishBaseLines.map { SudokuUnit(orientation: baseOrientation, index: $0) }
                        + coreCrossLines.map { SudokuUnit(orientation: crossOrientation, index: $0) }
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        reasoning: HintReasoning(
                            actions: removals,
                            focusDigits: [digit],
                            units: fishUnits,
                            components: [
                                .base(fishPositions.subtracting(fins), candidates: [digit]),
                                .fin(fins, candidates: [digit]),
                                .eliminated(eliminationCells, candidates: [digit])
                            ]
                        )
                    )
                }
            }
        }

        return nil
    }
}
