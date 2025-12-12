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
    // get the technique for the current variant
    private static func fishTechnique(for n: Int, includesFin: Bool) -> HintTechnique {
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

    /// Detects fins in a row-based fish pattern
    /// Returns (coreCols, finPositions) or nil if not a valid finned fish
    private static func detectRowBasedFins(
        digit: Int,
        fishRows: Set<Int>,
        allCols: Set<Int>,
        rowToCols: [Int: Set<Int>],
        n: Int,
        state: BoardState
    ) -> (coreCols: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Count how many rows each column appears in
        var colCounts: [Int: Int] = [:]
        for col in allCols {
            var count = 0
            for row in fishRows {
                if rowToCols[row]?.contains(col) == true {
                    count += 1
                }
            }
            colCounts[col] = count
        }

        // Core columns should appear in n rows (or n-1 for some patterns)
        // Fin columns appear in fewer rows (usually 1)
        // Sort by count descending, then by column number ascending for determinism
        let sortedCols = allCols.sorted {
            if colCounts[$0]! != colCounts[$1]! {
                return colCounts[$0]! > colCounts[$1]!
            }
            return $0 < $1
        }

        // Try different combinations when counts are equal
        guard sortedCols.count >= n else { return nil }

        // If columns have clearly different counts, use the standard approach
        let maxCount = colCounts[sortedCols[0]]!
        let nthCount = colCounts[sortedCols[min(n-1, sortedCols.count-1)]]!

        if maxCount > nthCount || sortedCols.count == n {
            // Standard case: clear distinction OR exact fit
            let coreCols = Set(sortedCols.prefix(n))
            let finCols = allCols.subtracting(coreCols)

            if let result = validateRowBasedFins(
                digit: digit,
                fishRows: fishRows,
                coreCols: coreCols,
                finCols: finCols,
                rowToCols: rowToCols,
                state: state
            ) {
                return result
            }
        } else {
            // Ambiguous case: try all combinations of n columns
            let colsArray = Array(sortedCols)
            for combo in combinations(of: colsArray, choose: n) {
                let coreCols = Set(combo)
                let finCols = allCols.subtracting(coreCols)

                if let result = validateRowBasedFins(
                    digit: digit,
                    fishRows: fishRows,
                    coreCols: coreCols,
                    finCols: finCols,
                    rowToCols: rowToCols,
                    state: state
                ) {
                    return result
                }
            }
        }

        return nil
    }

    /// Helper to validate fins for row-based fish
    private static func validateRowBasedFins(
        digit: Int,
        fishRows: Set<Int>,
        coreCols: Set<Int>,
        finCols: Set<Int>,
        rowToCols: [Int: Set<Int>],
        state: BoardState
    ) -> (coreCols: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Find fin positions - candidates in fin columns
        var fins = Set<Puzzle.Index>()
        for row in fishRows {
            guard let rowCols = rowToCols[row] else { continue }
            for col in finCols {
                if rowCols.contains(col) {
                    let position = Puzzle.Index(row: row, column: col)
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

        // All fins must be in the same box
        guard let firstFin = fins.first else { return nil }
        let finBox = (firstFin.row / 3, firstFin.column / 3)
        for fin in fins {
            let box = (fin.row / 3, fin.column / 3)
            if box != finBox {
                return nil
            }
        }

        // Verify that this partition would produce eliminations
        var hasEliminations = false
        for col in coreCols {
            for row in 0..<9 where fishRows.contains(row) == false {
                let position = Puzzle.Index(row: row, column: col)
                if state.grid[position.row][position.column] == 0 {
                    let candidates = state.pencilMarks[position.row][position.column]
                    if candidates.contains(digit) {
                        let cellNeighbours = Self.getNeighbours(of:position, in: state)
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

        return (coreCols, fins)
    }

    /// Detects fins in a column-based fish pattern
    /// Returns (coreRows, finPositions) or nil if not a valid finned fish
    private static func detectColumnBasedFins(
        digit: Int,
        fishCols: Set<Int>,
        allRows: Set<Int>,
        colToRows: [Int: Set<Int>],
        n: Int,
        state: BoardState
    ) -> (coreRows: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Count how many columns each row appears in
        var rowCounts: [Int: Int] = [:]
        for row in allRows {
            var count = 0
            for col in fishCols {
                if colToRows[col]?.contains(row) == true {
                    count += 1
                }
            }
            rowCounts[row] = count
        }

        // Core rows should appear in n columns (or n-1 for some patterns)
        // Fin rows appear in fewer columns (usually 1)
        // Sort by count descending, then by row number ascending for determinism
        let sortedRows = allRows.sorted {
            if rowCounts[$0]! != rowCounts[$1]! {
                return rowCounts[$0]! > rowCounts[$1]!
            }
            return $0 < $1
        }

        // Try different combinations when counts are equal
        // This handles cases where all rows appear in all columns equally
        guard sortedRows.count >= n else { return nil }

        // If rows have clearly different counts, use the standard approach
        let maxCount = rowCounts[sortedRows[0]]!
        let nthCount = rowCounts[sortedRows[min(n-1, sortedRows.count-1)]]!

        if maxCount > nthCount || sortedRows.count == n {
            // Standard case: clear distinction OR exact fit
            let coreRows = Set(sortedRows.prefix(n))
            let finRows = allRows.subtracting(coreRows)

            if let result = validateFins(
                digit: digit,
                fishCols: fishCols,
                coreRows: coreRows,
                finRows: finRows,
                colToRows: colToRows,
                state: state
            ) {
                return result
            }
        } else {
            // Ambiguous case: try all combinations of n rows
            let rowsArray = Array(sortedRows)
            for combo in combinations(of: rowsArray, choose: n) {
                let coreRows = Set(combo)
                let finRows = allRows.subtracting(coreRows)

                if let result = validateFins(
                    digit: digit,
                    fishCols: fishCols,
                    coreRows: coreRows,
                    finRows: finRows,
                    colToRows: colToRows,
                    state: state
                ) {
                    return result
                }
            }
        }

        return nil
    }

    /// Helper to validate fins for column-based fish
    private static func validateFins(
        digit: Int,
        fishCols: Set<Int>,
        coreRows: Set<Int>,
        finRows: Set<Int>,
        colToRows: [Int: Set<Int>],
        state: BoardState
    ) -> (coreRows: Set<Int>, fins: Set<Puzzle.Index>)? {
        // Find fin positions - candidates in fin rows
        var fins = Set<Puzzle.Index>()
        for col in fishCols {
            guard let colRows = colToRows[col] else { continue }
            for row in finRows {
                if colRows.contains(row) {
                    let position = Puzzle.Index(row: row, column: col)
                    if state.pencilMarks[position.row][position.column].contains(digit) {
                        fins.insert(position)
                    }
                }
            }
        }

        // Must have at least one fin
        guard fins.isEmpty == false else { return nil }

        // All fins must be in the same box
        guard let firstFin = fins.first else { return nil }
        let finBox = (firstFin.row / 3, firstFin.column / 3)
        for fin in fins {
            let box = (fin.row / 3, fin.column / 3)
            if box != finBox {
                return nil
            }
        }

        // Verify that this partition would produce eliminations
        var hasEliminations = false
        for row in coreRows {
            for col in 0..<9 where fishCols.contains(col) == false {
                let position = Puzzle.Index(row: row, column: col)
                if state.grid[position.row][position.column] == 0 {
                    let candidates = state.pencilMarks[position.row][position.column]
                    if candidates.contains(digit) {
                        let cellNeighbours = Self.getNeighbours(of:position, in: state)
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

        return (coreRows, fins)
    }

    // MARK: - Main Fish Finding

    /// Find fish patterns of size n (2 for X-Wing, 3 for Swordfish, 4 for Jellyfish)
    static func findNFish(n: Int, requiresFin: Bool = false, in state: BoardState) -> HintStep? {
        // Check row-based fish
        if let hint = findRowBasedNFish(
            n: n,
            requiresFin: requiresFin,
            state: state
        ) {
            return hint
        }

        // Check column-based fish
        if let hint = findColumnBasedNFish(
            n: n,
            requiresFin: requiresFin,
            state: state
        ) {
            return hint
        }

        return nil
    }

    private static func findRowBasedNFish(
        n: Int,
        requiresFin: Bool,
        state: BoardState
    ) -> HintStep? {
        // Pre-compute pencil marks for all cells to avoid repeated lookups
        let pencilMarks = state.pencilMarks

        // For each digit
        for digit in 1...9 {
            // Build a map of rows -> columns where digit appears as a candidate
            // Use OrderedDictionary for better iteration performance
            var rowToCols: [Int: Set<Int>] = [:]
            rowToCols.reserveCapacity(9)

            for row in 0..<9 {
                var candidateCols = Set<Int>()
                candidateCols.reserveCapacity(9)

                for col in 0..<9 where state.grid[row][col] == 0 {
                    if pencilMarks[row][col].contains(digit) {
                        candidateCols.insert(col)
                    }
                }

                // Include rows with 2+ candidate positions
                if candidateCols.count >= 2 {
                    rowToCols[row] = candidateCols
                }
            }

            // Need at least 2 rows with candidates
            if rowToCols.count < 2 {
                continue
            }

            // Check all combinations of n rows (sorted for determinism)
            let rows = Array(rowToCols.keys).sorted()
            for combo in combinations(of: rows, choose: n) {
                let fishRows = Set(combo)

                // Get union of all columns
                var allCols = Set<Int>()
                for row in fishRows {
                    if let cols = rowToCols[row] {
                        allCols.formUnion(cols)
                    }
                }

                // Check for perfect fish or finned fish
                var coreCols = allCols
                var fins = Set<Puzzle.Index>()
                var includesFin = false

                if allCols.count == n {
                    // Perfect fish
                    if requiresFin {
                        continue // Skip perfect fish when requiring fins
                    }
                    // Process as regular fish
                } else if allCols.count > n && allCols.count <= n + 2 {
                    // Potential finned fish
                    if requiresFin {
                        // Try to detect fins
                        if let finData = detectRowBasedFins(
                            digit: digit,
                            fishRows: fishRows,
                            allCols: allCols,
                            rowToCols: rowToCols,
                            n: n,
                            state: state
                        ) {
                            coreCols = finData.coreCols
                            fins = finData.fins
                            includesFin = true
                        } else {
                            continue // Not a valid finned fish
                        }
                    } else {
                        continue // Skip finned patterns when not requiring fins
                    }
                } else {
                    continue // Too many columns or not enough
                }

                // Create matrix of positions where the digit appears
                var fishPositions = Set<Puzzle.Index>()
                for row in fishRows {
                    for col in coreCols {
                        let position = Puzzle.Index(row: row, column: col)
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

                // Check if we can eliminate digit from other cells
                var removals: [HintAction] = []
                var eliminationCells = Set<Puzzle.Index>()

                for col in coreCols {
                    for row in 0..<9 where fishRows.contains(row) == false {
                        let position = Puzzle.Index(row: row, column: col)
                        if state.grid[position.row][position.column] == 0 {
                            let candidates = state.pencilMarks[position.row][position.column]
                            if candidates.contains(digit) {
                                // For finned fish, only eliminate if cell sees all fins
                                if includesFin {
                                    let cellNeighbours = Self.getNeighbours(of:position, in: state)
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
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        explanation: fishExplanation(
                            digit: digit,
                            fishPositions: fishPositions,
                            baseLines: Array(fishRows),
                            crossLines: Array(allCols),
                            orientation: .row,
                            eliminationCells: eliminationCells,
                            n: n,
                            fins: fins,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func findColumnBasedNFish(
        n: Int,
        requiresFin: Bool,
        state: BoardState
    ) -> HintStep? {
        // Pre-compute pencil marks for all cells to avoid repeated lookups
        let pencilMarks = state.pencilMarks

        // For each digit
        for digit in 1...9 {
            // Build a map of columns -> rows where digit appears as a candidate
            var colToRows: [Int: Set<Int>] = [:]
            colToRows.reserveCapacity(9)

            for col in 0..<9 {
                var candidateRows = Set<Int>()
                candidateRows.reserveCapacity(9)

                for row in 0..<9 where state.grid[row][col] == 0 {
                    if pencilMarks[row][col].contains(digit) {
                        candidateRows.insert(row)
                    }
                }

                // Include columns with 2+ candidate positions
                if candidateRows.count >= 2 {
                    colToRows[col] = candidateRows
                }
            }

            // Need at least 2 columns with candidates
            if colToRows.count < 2 {
                continue
            }

            // Check all combinations of n columns (sorted for determinism)
            let cols = Array(colToRows.keys).sorted()
            for combo in combinations(of: cols, choose: n) {
                let fishCols = Set(combo)

                // Get union of all rows
                var allRows = Set<Int>()
                for col in fishCols {
                    if let rows = colToRows[col] {
                        allRows.formUnion(rows)
                    }
                }

                // Check for perfect fish or finned fish
                var coreRows = allRows
                var fins = Set<Puzzle.Index>()
                var includesFin = false

                if allRows.count == n {
                    // Perfect fish
                    if requiresFin {
                        continue // Skip perfect fish when requiring fins
                    }
                    // Process as regular fish
                } else if allRows.count > n && allRows.count <= n + 2 {
                    // Potential finned fish
                    if requiresFin {
                        // Try to detect fins
                        if let finData = detectColumnBasedFins(
                            digit: digit,
                            fishCols: fishCols,
                            allRows: allRows,
                            colToRows: colToRows,
                            n: n,
                            state: state
                        ) {
                            coreRows = finData.coreRows
                            fins = finData.fins
                            includesFin = true
                        } else {
                            continue // Not a valid finned fish
                        }
                    } else {
                        continue // Skip finned patterns when not requiring fins
                    }
                } else {
                    continue // Too many rows or not enough
                }

                // Create matrix of positions where the digit appears
                var fishPositions = Set<Puzzle.Index>()
                for col in fishCols {
                    for row in coreRows {
                        let position = Puzzle.Index(row: row, column: col)
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

                // Ensure at least 2 of the n columns contain the digit
                let colsWithPositions = Set(fishPositions.map { $0.column })
                if colsWithPositions.count < 2 {
                    continue
                }

                // Check if we can eliminate digit from other cells
                var removals: [HintAction] = []
                var eliminationCells = Set<Puzzle.Index>()

                for row in coreRows {
                    for col in 0..<9 where fishCols.contains(col) == false {
                        let position = Puzzle.Index(row: row, column: col)
                        if state.grid[position.row][position.column] == 0 {
                            let candidates = state.pencilMarks[position.row][position.column]
                            if candidates.contains(digit) {
                                // For finned fish, only eliminate if cell sees all fins
                                if includesFin {
                                    let cellNeighbours = Self.getNeighbours(of:position, in: state)
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
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        explanation: fishExplanation(
                            digit: digit,
                            fishPositions: fishPositions,
                            baseLines: Array(fishCols),
                            crossLines: Array(allRows),
                            orientation: .column,
                            eliminationCells: eliminationCells,
                            n: n,
                            fins: fins,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func fishExplanation(
        digit: Int,
        fishPositions: Set<Puzzle.Index>,
        baseLines: [Int],
        crossLines: [Int],
        orientation: Puzzle.Index.Orientation,
        eliminationCells: Set<Puzzle.Index>,
        n: Int,
        fins: Set<Puzzle.Index> = [],
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        let hasFins = fins.isEmpty == false

        // Determine the fish name and orientations
        let fishName: LocalizedStringResource
        switch n {
        case 2:
            fishName = hasFins ?
                LocalizedStringResource("Finned X-Wing", bundle: .module) :
                LocalizedStringResource("X-Wing", bundle: .module)
        case 3:
            fishName = hasFins ?
                LocalizedStringResource("Finned Swordfish", bundle: .module) :
                LocalizedStringResource("Swordfish", bundle: .module)
        case 4:
            fishName = hasFins ?
                LocalizedStringResource("Finned Jellyfish", bundle: .module) :
                LocalizedStringResource("Jellyfish", bundle: .module)
        default:
            fishName = hasFins ?
                LocalizedStringResource("Finned \(n)-Fish", bundle: .module) :
                LocalizedStringResource("\(n)-Fish", bundle: .module)
        }

        let baseOrientation = orientation == .row ?
            LocalizedStringResource("rows", bundle: .module) :
            LocalizedStringResource("columns", bundle: .module)
        let crossOrientation = orientation == .row ?
            LocalizedStringResource("columns", bundle: .module) :
            LocalizedStringResource("rows", bundle: .module)

        let baseLinesText = baseLines.map { "\($0 + 1)" }.joined(separator: ", ")
        let crossLinesText = crossLines.map { "\($0 + 1)" }.joined(separator: ", ")

        // Step 1: Identify the fish pattern
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at \(baseOrientation) \(baseLinesText) and \(crossOrientation) \(crossLinesText) forming a \(fishName) pattern for digit \(digit):", bundle: .module),
                highlightedCells: fishPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Explain the pattern
        let countName: LocalizedStringResource
        switch n {
        case 2: countName = LocalizedStringResource("two", bundle: .module)
        case 3: countName = LocalizedStringResource("three", bundle: .module)
        case 4: countName = LocalizedStringResource("four", bundle: .module)
        default: countName = LocalizedStringResource("\(n)", bundle: .module)
        }

        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("In these \(countName) \(baseOrientation), the digit \(digit) can only appear in \(countName) \(crossOrientation).", bundle: .module),
                highlightedCells: fishPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )

        // Step 3: Explain the constraint
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("This means \(digit) must be placed in exactly \(countName) of these cells - one in each \(baseOrientation).", bundle: .module),
                highlightedCells: fishPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        value: digit,
                        highlightType: .action
                    )
                }
            )
        )

        // Step 4: Show fins if present
        if hasFins {
            steps.append(
                HintExplanationStep(
                    text: LocalizedStringResource("However, this pattern has extra candidates (fins) that prevent it from being a perfect fish:", bundle: .module),
                    highlightedCells: fins.map { index in
                        HintExplanationStepHighlight(
                            cell: index,
                            candidates: [digit],
                            highlightType: .secondary
                        )
                    }
                )
            )

            steps.append(
                HintExplanationStep(
                    text: LocalizedStringResource("Because of the fins, eliminations are restricted to cells that can see all fin positions.", bundle: .module),
                    highlightedCells: fins.map { index in
                        HintExplanationStepHighlight(
                            cell: index,
                            candidates: [digit],
                            highlightType: .secondary
                        )
                    } + fishPositions.subtracting(fins).map { index in
                        HintExplanationStepHighlight(
                            cell: index,
                            candidates: [digit],
                            highlightType: .primary
                        )
                    }
                )
            )
        }

        // Final step: Show the eliminations
        let eliminationText = hasFins ?
            LocalizedStringResource("Therefore, \(digit) can be eliminated from cells in the core \(crossOrientation) that see all fins.", bundle: .module) :
            LocalizedStringResource("Therefore, \(digit) can be eliminated from all other cells in these \(countName) \(crossOrientation).", bundle: .module)

        steps.append(
            HintExplanationStep(
                text: eliminationText,
                highlightedCells: eliminationCells.map { pos in
                    HintExplanationStepHighlight(
                        cell: pos,
                        candidates: [digit],
                        highlightType: .warning
                    )
                }
            )
        )

        return steps
    }
}
