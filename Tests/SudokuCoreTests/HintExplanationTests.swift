import Testing
@testable import SudokuCore

struct HintExplanationTests {

    // MARK: - Test Data

    /// Solve techniques where the final explanation step should use `.success` highlight.
    private static let solveTechniques: Set<HintTechnique> = [
        .nakedSingle, .hiddenSingle
    ]

    /// Expected step count ranges for each technique.
    static let expectedStepCounts: [StepCountExpectation] = [
        .init(.nakedSingle, min: 2, max: 3),
        .init(.hiddenSingle, min: 3, max: 4),
        .init(.nakedPair, min: 3, max: 3),
        .init(.nakedTriple, min: 3, max: 3),
        .init(.nakedQuad, min: 3, max: 3),
        .init(.hiddenPair, min: 3, max: 3),
        .init(.hiddenTriple, min: 3, max: 3),
        .init(.hiddenQuad, min: 3, max: 3),
        .init(.lockedCandidatesPointing, min: 5, max: 5),
        .init(.lockedCandidatesClaiming, min: 3, max: 3),
        .init(.xWing, min: 4, max: 4),
        .init(.swordfish, min: 4, max: 4),
        .init(.jellyfish, min: 4, max: 4),
        .init(.finnedXWing, min: 6, max: 6),
        .init(.finnedSwordfish, min: 6, max: 6),
        .init(.finnedJellyfish, min: 6, max: 6),
        .init(.skyscraper, min: 4, max: 4),
        .init(.xyWing, min: 4, max: 4),
        .init(.yWing, min: 4, max: 4),
        .init(.xyzWing, min: 4, max: 4),
        .init(.twoStringKite, min: 4, max: 4),
        .init(.emptyRectangle, min: 4, max: 4),
        .init(.wWing, min: 4, max: 4),
    ]

    struct StepCountExpectation: Sendable, CustomTestStringConvertible {
        let technique: HintTechnique
        let minSteps: Int
        let maxSteps: Int

        var testDescription: String { technique.rawValue }

        init(_ technique: HintTechnique, min: Int, max: Int) {
            self.technique = technique
            self.minSteps = min
            self.maxSteps = max
        }
    }

    // MARK: - Helpers

    private func applyHint(_ hint: HintStep, to state: BoardState) -> BoardState {
        var newGrid = state.grid
        var newPencilMarks = state.pencilMarks
        for action in hint.actions {
            switch action.action {
            case .solveAs(let value):
                newGrid[action.position.row][action.position.column] = value
                newPencilMarks[action.position.row][action.position.column] = []
            case .ruleOut(let value):
                newPencilMarks[action.position.row][action.position.column].remove(value)
            case .pencilIn(let value):
                newPencilMarks[action.position.row][action.position.column].insert(value)
            case .clear:
                newPencilMarks[action.position.row][action.position.column] = []
            }
        }
        let newValidOptions = Validator.validOptions(for: newGrid)
        return BoardState(
            grid: newGrid,
            pencilMarks: newPencilMarks,
            validOptions: newValidOptions
        )
    }

    // MARK: - Test 1: Every hint produces valid explanation steps

    @Test("Every hint produces valid explanation steps", arguments: HintTests.testGrids)
    func explanationStepsAreValid(technique: HintTechnique, gridStrings: [String]) {
        for gridString in gridStrings {
            let state: BoardState
            do {
                state = try BoardStateParser.parse(gridString)
            } catch {
                Issue.record("Failed to parse grid for \(technique.rawValue): \(error)")
                continue
            }

            guard let hint = HintFinder.findHint(for: technique, in: state) else {
                Issue.record("Expected to find \(technique.rawValue) hint")
                continue
            }

            #expect(
                hint.explanation.isEmpty == false,
                "Explanation should not be empty for \(technique.rawValue)"
            )

            for (index, step) in hint.explanation.enumerated() {
                #expect(
                    step.highlightedCells.isEmpty == false,
                    "Step \(index) of \(technique.rawValue) should have highlighted cells"
                )
            }
        }
    }

    // MARK: - Test 2: Explanation step counts match expected ranges

    @Test("Explanation step counts match expected ranges", arguments: expectedStepCounts)
    func explanationStepCount(expectation: StepCountExpectation) {
        guard let (_, gridStrings) = HintTests.testGrids.first(
            where: { $0.0 == expectation.technique }
        ) else {
            Issue.record("No test grid found for \(expectation.technique.rawValue)")
            return
        }
        guard let gridString = gridStrings.first else {
            Issue.record("Empty grid strings for \(expectation.technique.rawValue)")
            return
        }

        let state: BoardState
        do {
            state = try BoardStateParser.parse(gridString)
        } catch {
            Issue.record("Failed to parse grid for \(expectation.technique.rawValue): \(error)")
            return
        }

        guard let hint = HintFinder.findHint(for: expectation.technique, in: state) else {
            Issue.record("Expected to find \(expectation.technique.rawValue) hint")
            return
        }

        let stepCount = hint.explanation.count
        #expect(
            stepCount >= expectation.minSteps && stepCount <= expectation.maxSteps,
            "\(expectation.technique.rawValue) produced \(stepCount) steps, expected \(expectation.minSteps)–\(expectation.maxSteps)"
        )
    }

    // MARK: - Test 3: Final step uses correct highlight type

    @Test("Final step uses correct highlight type", arguments: HintTests.testGrids)
    func finalStepHighlightType(technique: HintTechnique, gridStrings: [String]) {
        guard let gridString = gridStrings.first else { return }

        let state: BoardState
        do {
            state = try BoardStateParser.parse(gridString)
        } catch {
            Issue.record("Failed to parse grid for \(technique.rawValue): \(error)")
            return
        }

        guard let hint = HintFinder.findHint(for: technique, in: state) else {
            Issue.record("Expected to find \(technique.rawValue) hint")
            return
        }

        guard let finalStep = hint.explanation.last else {
            Issue.record("Explanation should not be empty for \(technique.rawValue)")
            return
        }

        if Self.solveTechniques.contains(technique) {
            let hasSuccess = finalStep.highlightedCells.contains {
                $0.highlightType == .success
            }
            #expect(
                hasSuccess,
                "Solve technique \(technique.rawValue) final step should have .success highlight"
            )
        } else {
            let hasWarning = finalStep.highlightedCells.contains {
                $0.highlightType == .warning
            }
            #expect(
                hasWarning,
                "Elimination technique \(technique.rawValue) final step should have .warning highlight"
            )
        }
    }

    // MARK: - Test 4: Applying hint changes board state

    @Test("Applying hint changes board state", arguments: HintTests.testGrids)
    func hintApplicationChangesState(technique: HintTechnique, gridStrings: [String]) {
        guard let gridString = gridStrings.first else { return }

        let state: BoardState
        do {
            state = try BoardStateParser.parse(gridString)
        } catch {
            Issue.record("Failed to parse grid for \(technique.rawValue): \(error)")
            return
        }

        guard let hint = HintFinder.findHint(for: technique, in: state) else {
            Issue.record("Expected to find \(technique.rawValue) hint")
            return
        }

        let newState = applyHint(hint, to: state)
        #expect(
            newState != state,
            "Applying \(technique.rawValue) hint should change the board state"
        )
    }
}
