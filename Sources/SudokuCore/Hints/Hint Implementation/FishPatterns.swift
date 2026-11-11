//
//  FishPatterns.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Fish Pattern Technique (Generic for X-Wing, Swordfish, Jellyfish)
extension HintFinder {
    /// Maps the fish size `n` and finned status to the corresponding `TechniqueInfo`.
    /// - Parameters:
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - includesFin: Whether the pattern has fin candidates.
    /// - Returns: The matching `TechniqueInfo`.
    private static func fishTechnique(for n: Int, includesFin: Bool) -> TechniqueInfo {
        let techniques: [TechniqueInfo] = includesFin
            ? [.finnedXWing, .finnedSwordfish, .finnedJellyfish]
            : [.xWing, .swordfish, .jellyfish]
        return techniques[n - 2]
    }

    // The finders below work on bitmasks rather than sets. A base line's candidates for a
    // digit are a 9-bit mask of the cross lines they're in, a set of lines is a 9-bit mask of
    // line indices, and a set of cells is a `UInt128` (see `LookupTables.peerMasks`). Fish are
    // tried at every state every easier technique fails at, six sizes and kinds each time, so
    // the search has to be cheap when it finds nothing.

    /// The lines in a 9-bit line mask, ascending.
    private static func lines(in mask: Int) -> [Int] {
        (0..<9).filter { mask & (1 << $0) != 0 }
    }

    // MARK: - Fin Detection Helpers

    /// Detects fins in a fish pattern for either orientation.
    ///
    /// Fins are extra candidate positions that spill beyond the `n` core cross lines.
    /// Every `n`-element choice of core cross lines is tried, ordered by how many base lines
    /// each cross line appears in, and the remaining positions are treated as fins. The
    /// first partition that validates is returned.
    ///
    /// Nearly every fish that reaches here has no valid fins, so nothing is allocated until
    /// one does.
    ///
    /// - Parameters:
    ///   - digitBit: The candidate digit being analysed, as its bit in `candidates`.
    ///   - fishBaseLines: The base lines forming the fish, as a mask.
    ///   - allCrossLines: The union of cross lines across the fish's base lines, as a mask.
    ///   - crossLines: For each base line, the cross lines where the digit appears, as a mask.
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - cell: Converts (baseLine, crossLine) into a cell index for the orientation.
    ///   - candidates: Each empty cell's candidates as a bitmask, by cell index.
    /// - Returns: The `n` core cross lines as a mask and the fin cells, or `nil` if no valid
    ///   finned partition exists.
    private static func detectFins(
        digitBit: Int,
        fishBaseLines: Int,
        allCrossLines: Int,
        crossLines: [Int],
        n: Int,
        cell: (Int, Int) -> Int,
        candidates: [Int]
    ) -> (coreCrossLines: Int, fins: UInt128)? {
        // Core cross lines appear in the most base lines; fin cross lines appear in fewer.
        // Order them descending by frequency so the first n are the best core candidates,
        // ties broken by ascending index for deterministic output. A fish has at most six
        // cross lines here, kept four bits each in one integer, most frequent lowest.
        var sortedCrossLines = 0
        var crossLineCount = 0
        for frequency in stride(from: n, through: 1, by: -1) {
            for crossLine in 0..<9 where allCrossLines & (1 << crossLine) != 0 {
                var count = 0
                for baseLine in 0..<9 where fishBaseLines & (1 << baseLine) != 0 {
                    if crossLines[baseLine] & (1 << crossLine) != 0 { count += 1 }
                }
                if count == frequency {
                    sortedCrossLines |= crossLine << (4 * crossLineCount)
                    crossLineCount += 1
                }
            }
        }

        // Try every partition, most frequent lines first. Frequency alone can't pick the
        // core: a valid core line can appear in fewer base lines than a fin line does.
        // There are at most C(n+2, n) = 15 partitions, so the full search is cheap.
        for choice in LookupTables.choices(of: crossLineCount, choose: n) {
            var coreCrossLines = 0
            for index in choice {
                coreCrossLines |= 1 << ((sortedCrossLines >> (4 * index)) & 0xF)
            }
            if let fins = validateFins(
                digitBit: digitBit,
                fishBaseLines: fishBaseLines,
                coreCrossLines: coreCrossLines,
                finCrossLines: allCrossLines & ~coreCrossLines,
                crossLines: crossLines,
                cell: cell,
                candidates: candidates
            ) {
                return (coreCrossLines, fins)
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
    /// - Returns: The fin cells, or `nil` if the partition is invalid.
    private static func validateFins(
        digitBit: Int,
        fishBaseLines: Int,
        coreCrossLines: Int,
        finCrossLines: Int,
        crossLines: [Int],
        cell: (Int, Int) -> Int,
        candidates: [Int]
    ) -> UInt128? {
        // Fin positions: the fish's candidates in the fin cross lines. Every fin cross line
        // holds a base line's candidate, so there is at least one fin.
        var fins: UInt128 = 0
        for baseLine in 0..<9 where fishBaseLines & (1 << baseLine) != 0 {
            let inFinLines = crossLines[baseLine] & finCrossLines
            for crossLine in 0..<9 where inFinLines & (1 << crossLine) != 0 {
                fins |= LookupTables.cellBit(cell(baseLine, crossLine))
            }
        }
        guard fins != 0 else { return nil }

        // Same-box constraint: all fins must share one 3x3 box so that
        // eliminations can be confined to cells that see the entire fin group.
        let firstFin = fins.trailingZeroBitCount
        let finBox = LookupTables.unitMasks[18 + (firstFin / 27) * 3 + (firstFin % 9) / 3]
        guard fins & ~finBox == 0 else { return nil }

        // Elimination verification: scan core cross lines outside the fish base lines.
        // A candidate is only eliminable if the cell sees every fin (i.e. shares a
        // constraining unit with all fin positions). At least one such elimination must
        // exist for the partition to be useful.
        for crossLine in 0..<9 where coreCrossLines & (1 << crossLine) != 0 {
            for baseLine in 0..<9 where fishBaseLines & (1 << baseLine) == 0 {
                let target = cell(baseLine, crossLine)
                if candidates[target] & digitBit != 0, fins & ~LookupTables.peerMasks[target] == 0 {
                    return fins
                }
            }
        }
        return nil
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
        // Each empty cell's candidates as a bitmask (bit d set for digit d), by cell index
        var candidates = [Int](repeating: 0, count: 81)
        for row in 0..<9 {
            for column in 0..<9 where state.grid[row][column] == 0 {
                candidates[row * 9 + column] = state.pencilMarks[row][column].reduce(0) { $0 | (1 << $1) }
            }
        }

        if let hint = findNFishInOrientation(
            n: n, requiresFin: requiresFin, baseOrientation: .row, candidates: candidates)
        {
            return hint
        }
        if let hint = findNFishInOrientation(
            n: n, requiresFin: requiresFin, baseOrientation: .column, candidates: candidates)
        {
            return hint
        }
        return nil
    }

    /// Searches for a fish pattern in a single orientation (row-based or column-based).
    ///
    /// The algorithm iterates over each digit 1-9, works out for each base line the cross
    /// lines where the digit appears, then checks every `n`-combination of base lines. A
    /// perfect fish has exactly `n` cross lines; a finned fish has `n+1` or `n+2` cross lines
    /// with valid fins.
    ///
    /// - Parameters:
    ///   - n: The fish size (2 = X-Wing, 3 = Swordfish, 4 = Jellyfish).
    ///   - requiresFin: When `true`, only finned variants are returned.
    ///   - baseOrientation: Whether base lines are rows or columns.
    ///   - candidates: Each empty cell's candidates as a bitmask, by cell index.
    /// - Returns: A `HintStep` for the first valid fish found, or `nil`.
    private static func findNFishInOrientation(
        n: Int,
        requiresFin: Bool,
        baseOrientation: Puzzle.Index.Orientation,
        candidates: [Int]
    ) -> HintStep? {
        // `cell` maps (baseLine, crossLine) to a cell index for either orientation.
        let cell: (Int, Int) -> Int = baseOrientation == .row
            ? { base, cross in base * 9 + cross }
            : { base, cross in cross * 9 + base }
        let position = { (cell: Int) in Puzzle.Index(row: cell / 9, column: cell % 9) }

        // For each base line, the cross lines where the digit appears as a candidate, and
        // the base lines with 2+ candidate positions, which are the ones that take part.
        var crossLines = [Int](repeating: 0, count: 9)
        var baseLines: [Int] = []
        baseLines.reserveCapacity(9)

        // For each digit
        for digit in 1...9 {
            let digitBit = 1 << digit

            baseLines.removeAll(keepingCapacity: true)
            for baseLine in 0..<9 {
                crossLines[baseLine] = 0
                var mask = 0
                for crossLine in 0..<9 where candidates[cell(baseLine, crossLine)] & digitBit != 0 {
                    mask |= 1 << crossLine
                }
                if mask.nonzeroBitCount >= 2 {
                    crossLines[baseLine] = mask
                    baseLines.append(baseLine)
                }
            }

            // Need at least 2 base lines with candidates
            if baseLines.count < 2 {
                continue
            }

            // Check all combinations of n base lines, in ascending order for determinism
            for choice in LookupTables.choices(of: baseLines.count, choose: n) {
                var allCrossLines = 0
                var isBaseLine = 0
                for index in choice {
                    allCrossLines |= crossLines[baseLines[index]]
                    isBaseLine |= 1 << baseLines[index]
                }
                let crossLineCount = allCrossLines.nonzeroBitCount

                // Check for perfect fish or finned fish
                var coreCrossLines = allCrossLines
                var finCells: UInt128 = 0
                var includesFin = false

                if crossLineCount == n {
                    // Perfect fish: skipped when requiring fins
                    if requiresFin { continue }
                } else if crossLineCount > n && crossLineCount <= n + 2 {
                    // Potential finned fish: skipped unless requiring fins
                    guard requiresFin,
                        let finData = detectFins(
                            digitBit: digitBit,
                            fishBaseLines: isBaseLine,
                            allCrossLines: allCrossLines,
                            crossLines: crossLines,
                            n: n,
                            cell: cell,
                            candidates: candidates
                        )
                    else { continue }
                    coreCrossLines = finData.coreCrossLines
                    finCells = finData.fins
                    includesFin = true
                } else {
                    continue // Too many cross lines or not enough
                }

                // Check if we can eliminate digit from other cells: the core cross lines'
                // candidates outside the base lines. For a finned fish, only those that see
                // every fin.
                var eliminationCells: [Int] = []
                for crossLine in 0..<9 where coreCrossLines & (1 << crossLine) != 0 {
                    for baseLine in 0..<9 where isBaseLine & (1 << baseLine) == 0 {
                        let target = cell(baseLine, crossLine)
                        guard candidates[target] & digitBit != 0 else { continue }
                        if includesFin, finCells & ~LookupTables.peerMasks[target] != 0 { continue }
                        eliminationCells.append(target)
                    }
                }
                guard eliminationCells.isEmpty == false else { continue }

                let fishBaseLines = choice.map { baseLines[$0] }
                let coreLines = lines(in: coreCrossLines)
                // Ascending cell index, which is row then column
                var fins: [Int] = []
                var remainingFins = finCells
                while remainingFins != 0 {
                    fins.append(remainingFins.trailingZeroBitCount)
                    remainingFins &= remainingFins - 1
                }

                // The fish's candidates in its core cross lines. Every base line holds at
                // least two candidates, each in a core line or a fin.
                var basePositions: [Puzzle.Index] = []
                for baseLine in fishBaseLines {
                    for crossLine in coreLines where candidates[cell(baseLine, crossLine)] & digitBit != 0 {
                        basePositions.append(position(cell(baseLine, crossLine)))
                    }
                }

                let removals = eliminationCells.map { HintAction(position: position($0), ruleOut: digit) }
                let technique = fishTechnique(
                    for: n,
                    includesFin: includesFin
                )
                let crossOrientation: Puzzle.Index.Orientation = baseOrientation == .row ? .column : .row
                let fishUnits = fishBaseLines.map { SudokuUnit(orientation: baseOrientation, index: $0) }
                    + coreLines.map { SudokuUnit(orientation: crossOrientation, index: $0) }
                return HintStep(
                    actions: removals,
                    technique: technique,
                    reasoning: HintReasoning(
                        actions: removals,
                        focusDigits: [digit],
                        units: fishUnits,
                        components: [
                            .base(basePositions, candidates: [digit]),
                            .fin(fins.map(position), candidates: [digit]),
                            .eliminated(eliminationCells.map(position), candidates: [digit])
                        ]
                    )
                )
            }
        }

        return nil
    }
}
