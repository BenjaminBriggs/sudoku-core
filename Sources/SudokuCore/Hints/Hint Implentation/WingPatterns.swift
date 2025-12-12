//
//  WingPatterns.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Wing Pattern Techniques (XY-Wing, Y-Wing, XYZ-Wing)
extension HintFinder {
    /// Wing pattern types
    private enum WingType {
        case xy      // Pivot: 2 candidates, strict 1:1 sharing
        case y       // Pivot: 2 candidates, relaxed constraints
        case xyz     // Pivot: 3 candidates, wings must be neighbors
    }

    // MARK: - Public API

    static func findXYWing(in state: BoardState) -> HintStep? {
        findWingPattern(type: .xy, technique: .xyWing, in: state)
    }

    static func findYWing(in state: BoardState) -> HintStep? {
        findWingPattern(type: .y, technique: .yWing, in: state)
    }

    static func findXYZWing(in state: BoardState) -> HintStep? {
        findWingPattern(type: .xyz, technique: .xyzWing, in: state)
    }

    // MARK: - Generic Wing Finder

    private static func findWingPattern(
        type: WingType,
        technique: HintTechnique,
        in state: BoardState
    ) -> HintStep? {
        // Pre-compute grid and pencil marks for faster access
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Collect bi-value and tri-value cells
        var biValueCells: [(Puzzle.Index, Set<Int>)] = []
        var triValueCells: [(Puzzle.Index, Set<Int>)] = []
        biValueCells.reserveCapacity(20)
        triValueCells.reserveCapacity(20)

        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 {
                    let candidates = pencilMarks[row][col]
                    let count = candidates.count
                    if count == 2 {
                        biValueCells.append((Puzzle.Index(row: row, column: col), candidates))
                    } else if count == 3 {
                        triValueCells.append((Puzzle.Index(row: row, column: col), candidates))
                    }
                }
            }
        }

        // Select pivot cells based on wing type
        let pivotCells: [(Puzzle.Index, Set<Int>)]
        switch type {
        case .xy, .y:
            pivotCells = biValueCells
        case .xyz:
            pivotCells = triValueCells
        }

        // Need at least 3 cells total
        if pivotCells.isEmpty || biValueCells.count < 2 {
            return nil
        }

        // Try each pivot
        for (pivotPos, pivotCandidates) in pivotCells {
            if let hint = findWingWithPivot(
                type: type,
                technique: technique,
                pivot: (pivotPos, pivotCandidates),
                biValueCells: biValueCells,
                state: state
            ) {
                return hint
            }
        }

        return nil
    }

    private static func findWingWithPivot(
        type: WingType,
        technique: HintTechnique,
        pivot: (pos: Puzzle.Index, candidates: Set<Int>),
        biValueCells: [(Puzzle.Index, Set<Int>)],
        state: BoardState
    ) -> HintStep? {
        let (pivotPos, pivotCandidates) = pivot

        // For XYZ-Wing, filter wings to only neighbors of pivot
        let candidateWings: [(Puzzle.Index, Set<Int>)]
        if case .xyz = type {
            let pivotNeighbours = LookupTables.cellNeighbours[pivotPos.row][pivotPos.column]
            candidateWings = biValueCells.filter { pivotNeighbours.contains($0.0) && $0.0 != pivotPos }
        } else {
            candidateWings = biValueCells.filter { $0.0 != pivotPos }
        }

        // Try all combinations of two wings
        for wingAIndex in 0..<candidateWings.count {
            for wingBIndex in (wingAIndex+1)..<candidateWings.count {
                let (wingAPos, wingACandidates) = candidateWings[wingAIndex]
                let (wingBPos, wingBCandidates) = candidateWings[wingBIndex]

                // Validate wing pattern and get elimination digit
                guard let eliminationDigit = validateWingPattern(
                    type: type,
                    pivot: (pivotPos, pivotCandidates),
                    wingA: (wingAPos, wingACandidates),
                    wingB: (wingBPos, wingBCandidates)
                ) else {
                    continue
                }

                // Find elimination cells
                let eliminationCells = findEliminationCells(
                    type: type,
                    pivot: (pivotPos, pivotCandidates),
                    wingA: (wingAPos, wingACandidates),
                    wingB: (wingBPos, wingBCandidates),
                    digit: eliminationDigit,
                    state: state
                )

                if eliminationCells.isEmpty == false {
                    var removals: [HintAction] = []
                    removals.reserveCapacity(eliminationCells.count)
                    for cell in eliminationCells {
                        removals.append(HintAction(position: cell, ruleOut: eliminationDigit))
                    }

                    return HintStep(
                        actions: removals,
                        technique: technique,
                        explanation: wingExplanation(
                            type: type,
                            technique: technique,
                            pivot: (pivotPos, pivotCandidates),
                            wingA: (wingAPos, wingACandidates),
                            wingB: (wingBPos, wingBCandidates),
                            eliminationDigit: eliminationDigit,
                            eliminationCells: eliminationCells,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Pattern Validation

    private static func validateWingPattern(
        type: WingType,
        pivot: (pos: Puzzle.Index, candidates: Set<Int>),
        wingA: (pos: Puzzle.Index, candidates: Set<Int>),
        wingB: (pos: Puzzle.Index, candidates: Set<Int>)
    ) -> Int? {
        let (_, pivotCandidates) = pivot
        let (_, wingACandidates) = wingA
        let (_, wingBCandidates) = wingB

        switch type {
        case .xy:
            return validateXYWing(pivot: pivotCandidates, wingA: wingACandidates, wingB: wingBCandidates)

        case .y:
            return validateYWing(pivot: pivotCandidates, wingA: wingACandidates, wingB: wingBCandidates)

        case .xyz:
            return validateXYZWing(pivot: pivotCandidates, wingA: wingACandidates, wingB: wingBCandidates)
        }
    }

    private static func validateXYWing(
        pivot: Set<Int>,
        wingA: Set<Int>,
        wingB: Set<Int>
    ) -> Int? {
        // Pivot shares exactly 1 candidate with each wing
        let pivotWingACommon = pivot.intersection(wingA)
        guard pivotWingACommon.count == 1 else { return nil }

        let pivotWingBCommon = pivot.intersection(wingB)
        guard pivotWingBCommon.count == 1 else { return nil }

        let x = pivotWingACommon.first!
        let y = pivotWingBCommon.first!

        guard x != y else { return nil }

        // Wings share a common digit (the elimination digit)
        let z1 = wingA.subtracting([x]).first!
        let z2 = wingB.subtracting([y]).first!

        return z1 == z2 ? z1 : nil
    }

    private static func validateYWing(
        pivot: Set<Int>,
        wingA: Set<Int>,
        wingB: Set<Int>
    ) -> Int? {
        let pivotArray = Array(pivot)
        let x = pivotArray[0]
        let y = pivotArray[1]

        // Wing A must contain one of pivot's candidates
        guard wingA.contains(x) || wingA.contains(y) else { return nil }

        // Wing B must contain one of pivot's candidates
        guard wingB.contains(x) || wingB.contains(y) else { return nil }

        // Extract the non-pivot candidates from each wing
        let z1 = wingA.subtracting(pivot).first ?? 0
        let z2 = wingB.subtracting(pivot).first ?? 0

        // Both wings must share the same elimination digit
        return (z1 == z2 && z1 != 0) ? z1 : nil
    }

    private static func validateXYZWing(
        pivot: Set<Int>,
        wingA: Set<Int>,
        wingB: Set<Int>
    ) -> Int? {
        // Pivot must share at least one candidate with each wing
        let pivotWingACommon = pivot.intersection(wingA)
        guard pivotWingACommon.isEmpty == false else { return nil }

        let pivotWingBCommon = pivot.intersection(wingB)
        guard pivotWingBCommon.isEmpty == false else { return nil }

        // Wings must share exactly one common candidate
        let wingCommon = wingA.intersection(wingB)
        guard wingCommon.count == 1 else { return nil }

        let z = wingCommon.first!

        // The elimination digit must also be in the pivot
        return pivot.contains(z) ? z : nil
    }

    // MARK: - Elimination Cell Finding

    private static func findEliminationCells(
        type: WingType,
        pivot: (pos: Puzzle.Index, candidates: Set<Int>),
        wingA: (pos: Puzzle.Index, candidates: Set<Int>),
        wingB: (pos: Puzzle.Index, candidates: Set<Int>),
        digit: Int,
        state: BoardState
    ) -> Set<Puzzle.Index> {
        let (pivotPos, _) = pivot
        let (wingAPos, _) = wingA
        let (wingBPos, _) = wingB

        let wingANeighbours = LookupTables.cellNeighbours[wingAPos.row][wingAPos.column]
        let wingBNeighbours = LookupTables.cellNeighbours[wingBPos.row][wingBPos.column]

        // For XYZ-Wing, cells must see all three cells
        // For XY/Y-Wing, cells must see both wings
        let potentialCells: Set<Puzzle.Index>
        if case .xyz = type {
            let pivotNeighbours = LookupTables.cellNeighbours[pivotPos.row][pivotPos.column]
            potentialCells = pivotNeighbours.intersection(wingANeighbours).intersection(wingBNeighbours)
        } else {
            potentialCells = wingANeighbours.intersection(wingBNeighbours)
        }

        // Pre-compute grid and pencil marks for faster access
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Filter to cells that actually contain the elimination digit
        var eliminationCells = Set<Puzzle.Index>()
        eliminationCells.reserveCapacity(potentialCells.count)

        for position in potentialCells {
            if grid[position.row][position.column] == 0 {
                if pencilMarks[position.row][position.column].contains(digit) {
                    eliminationCells.insert(position)
                }
            }
        }

        return eliminationCells
    }

    // MARK: - Explanation Generation

    private static func wingExplanation(
        type: WingType,
        technique: HintTechnique,
        pivot: (pos: Puzzle.Index, candidates: Set<Int>),
        wingA: (pos: Puzzle.Index, candidates: Set<Int>),
        wingB: (pos: Puzzle.Index, candidates: Set<Int>),
        eliminationDigit: Int,
        eliminationCells: Set<Puzzle.Index>,
        state: BoardState
    ) -> [HintExplanationStep] {
        let (pivotPos, pivotCandidates) = pivot
        let (wingAPos, wingACandidates) = wingA
        let (wingBPos, wingBCandidates) = wingB

        var steps: [HintExplanationStep] = []

        // Wing name
        let wingName: LocalizedStringResource
        switch type {
        case .xy:
            wingName = LocalizedStringResource("XY-Wing", bundle: .module)
        case .y:
            wingName = LocalizedStringResource("Y-Wing", bundle: .module)
        case .xyz:
            wingName = LocalizedStringResource("XYZ-Wing", bundle: .module)
        }

        // Step 1: Identify the pattern
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at these three cells forming a \(wingName) pattern:", bundle: .module),
                highlightedCells: [
                    HintExplanationStepHighlight(
                        cell: pivotPos,
                        label: "Pivot",
                        candidates: state.pencilMarks[pivotPos.row][pivotPos.column]
                    ),
                    HintExplanationStepHighlight(
                        cell: wingAPos,
                        label: "Wing A",
                        candidates: state.pencilMarks[wingAPos.row][wingAPos.column]
                    ),
                    HintExplanationStepHighlight(
                        cell: wingBPos,
                        label: "Wing B",
                        candidates: state.pencilMarks[wingBPos.row][wingBPos.column]
                    )
                ]
            )
        )

        // Step 2: Explain the pattern logic (type-specific)
        let logicText: LocalizedStringResource
        switch type {
        case .xy, .y:
            logicText = LocalizedStringResource("The pivot cell shares one candidate with each wing. Both wings contain \(eliminationDigit) as their second candidate.", bundle: .module)
        case .xyz:
            logicText = LocalizedStringResource("The pivot cell has 3 candidates. Each wing shares one candidate with the pivot, and both wings share \(eliminationDigit) as their second candidate.", bundle: .module)
        }

        steps.append(
            HintExplanationStep(
                text: logicText,
                highlightedCells: [
                    HintExplanationStepHighlight(cell: pivotPos, label: "Pivot", candidates: pivotCandidates),
                    HintExplanationStepHighlight(cell: wingAPos, label: "Wing A", candidates: wingACandidates),
                    HintExplanationStepHighlight(cell: wingBPos, label: "Wing B", candidates: wingBCandidates)
                ]
            )
        )

        // Step 3: Explain the elimination
        let eliminationText: LocalizedStringResource
        if case .xyz = type {
            eliminationText = LocalizedStringResource("No matter which value goes in the pivot, at least one of the wings must contain \(eliminationDigit).", bundle: .module)
        } else {
            eliminationText = LocalizedStringResource("Either way, \(eliminationDigit) must appear in one of the wing cells.", bundle: .module)
        }

        steps.append(
            HintExplanationStep(
                text: eliminationText,
                highlightedCells: [
                    HintExplanationStepHighlight(cell: pivotPos, candidates: pivotCandidates),
                    HintExplanationStepHighlight(cell: wingAPos, candidates: wingACandidates),
                    HintExplanationStepHighlight(cell: wingBPos, candidates: wingBCandidates)
                ]
            )
        )

        // Step 4: Show eliminations
        let seeText: LocalizedStringResource
        if case .xyz = type {
            seeText = LocalizedStringResource("Therefore, \(eliminationDigit) can be removed from any cell that sees all three cells in the pattern.", bundle: .module)
        } else {
            seeText = LocalizedStringResource("Therefore, \(eliminationDigit) can be removed from any cell that sees both wings.", bundle: .module)
        }

        steps.append(
            HintExplanationStep(
                text: seeText,
                highlightedCells: eliminationCells.map { cell in
                    HintExplanationStepHighlight(cell: cell, highlightType: .warning)
                }
            )
        )

        return steps
    }
}
