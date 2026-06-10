//
//  HintReasoningTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 10/06/2026.
//

import Testing

@testable import SudokuCore

struct HintReasoningTests {

    // MARK: - Helpers

    /// Resolves a board state and hint for a grid string, recording an issue if either fails.
    private func hint(
        for technique: HintTechnique,
        gridString: String
    ) -> (state: BoardState, hint: HintStep)? {
        let state: BoardState
        do {
            state = try BoardStateParser.parse(gridString)
        } catch {
            Issue.record("Failed to parse grid string for \(technique.rawValue): \(error)")
            return nil
        }
        guard let hint = HintFinder.findHint(for: technique, in: state) else {
            Issue.record("Expected \(technique.rawValue) hint in \(gridString)")
            return nil
        }
        return (state, hint)
    }

    // MARK: - Reasoning mirrors the hint's actions

    @Test("Reasoning placements and eliminations mirror the hint actions", arguments: HintTests.testGrids)
    func reasoningMirrorsActions(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            guard let (_, hint) = hint(for: technique, gridString: gridString) else { continue }

            let expectedPlacements = hint.actions.compactMap { action -> CandidateRef? in
                if case .solveAs(let digit) = action.action {
                    return CandidateRef(position: action.position, digit: digit)
                }
                return nil
            }
            let expectedEliminations = hint.actions.compactMap { action -> CandidateRef? in
                if case .ruleOut(let digit) = action.action {
                    return CandidateRef(position: action.position, digit: digit)
                }
                return nil
            }

            #expect(
                hint.reasoning.placements.count == expectedPlacements.count,
                "\(technique.rawValue): placement count mismatch in \(gridString)"
            )
            #expect(
                expectedPlacements.allSatisfy { hint.reasoning.placements.contains($0) },
                "\(technique.rawValue): placements do not mirror actions in \(gridString)"
            )
            #expect(
                hint.reasoning.eliminations.count == expectedEliminations.count,
                "\(technique.rawValue): elimination count mismatch in \(gridString)"
            )
            #expect(
                expectedEliminations.allSatisfy { hint.reasoning.eliminations.contains($0) },
                "\(technique.rawValue): eliminations do not mirror actions in \(gridString)"
            )
        }
    }

    // MARK: - Reasoning is consistent with the board it was generated from

    @Test("Reasoning is consistent with its source board", arguments: HintTests.testGrids)
    func reasoningIsConsistentWithSourceBoard(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            guard let (state, hint) = hint(for: technique, gridString: gridString) else { continue }

            let problems = hint.reasoning.inconsistencies(in: state)
            #expect(
                problems.isEmpty,
                "\(technique.rawValue): reasoning inconsistent with source board in \(gridString): \(problems)"
            )
        }
    }

    // MARK: - Reasoning carries structural premises

    @Test("Reasoning records focus digits and components", arguments: HintTests.testGrids)
    func reasoningHasStructure(technique: HintTechnique, gridStrings: [String]) async {
        for gridString in gridStrings {
            guard let (_, hint) = hint(for: technique, gridString: gridString) else { continue }

            #expect(
                hint.reasoning.focusDigits.isEmpty == false,
                "\(technique.rawValue): expected focus digits in \(gridString)"
            )
            #expect(
                hint.reasoning.components.isEmpty == false,
                "\(technique.rawValue): expected components in \(gridString)"
            )
            // No component should be recorded with zero cells.
            #expect(
                hint.reasoning.components.allSatisfy { $0.cells.isEmpty == false },
                "\(technique.rawValue): a component had no cells in \(gridString)"
            )
        }
    }

    // MARK: - Technique-specific structure

    @Test("Naked single reasoning has a subject and a single placement")
    func nakedSingleStructure() async {
        for gridString in HintTests.testGrids.first(where: { $0.0 == .nakedSingle })?.1 ?? [] {
            guard let (_, hint) = hint(for: .nakedSingle, gridString: gridString) else { continue }
            #expect(hint.reasoning.placements.count == 1)
            #expect(hint.reasoning.components.contains { $0.role == .subject })
        }
    }

    @Test("XY-Wing reasoning has exactly one pivot and one wing component")
    func wingStructure() async {
        for gridString in HintTests.testGrids.first(where: { $0.0 == .xyWing })?.1 ?? [] {
            guard let (_, hint) = hint(for: .xyWing, gridString: gridString) else { continue }
            #expect(hint.reasoning.components.filter { $0.role == .pivot }.count == 1)
            let wing = hint.reasoning.components.first { $0.role == .wing }
            #expect(wing?.cells.count == 2, "XY-Wing should record two pincer cells")
        }
    }

    // MARK: - Inconsistency detection (the debugging use case)

    @Test("inconsistencies(in:) flags a hint that no longer applies")
    func detectsStaleHint() async {
        guard let gridString = HintTests.testGrids.first(where: { $0.0 == .nakedSingle })?.1.first,
              let (state, hint) = hint(for: .nakedSingle, gridString: gridString),
              let placement = hint.reasoning.placements.first
        else {
            Issue.record("Could not set up a naked single hint")
            return
        }

        // Mutate the board so the hint's target cell is already filled — the hint is now stale.
        var mutated = state
        mutated.grid[placement.position.row][placement.position.column] = placement.digit
        mutated.pencilMarks[placement.position.row][placement.position.column] = []

        let problems = hint.reasoning.inconsistencies(in: mutated)
        #expect(
            problems.isEmpty == false,
            "Expected inconsistencies once the target cell is filled"
        )
    }
}
