import Testing
@testable import SudokuCore

@Suite("Solve path steps keep their reasoning")
struct SolveStepReasoningTests {
    /// Solved by singles and Pointing.
    private let needsPointing: [[Int]] = Solution.cells(
        from: "020608000580009700000040000370000500600000004008000013000020000009800036000306090"
    )

    @Test("Steps beyond singles carry reasoning whose eliminations are the step's own")
    func reasoningMatchesTheActions() throws {
        let path = SolvePathEmitter.emit(from: needsPointing)
        let beyondSingles = path.steps.filter { $0.technique.isSingle == false }
        try #require(beyondSingles.isEmpty == false)
        for step in beyondSingles {
            #expect(step.reasoning.components.isEmpty == false)
            let ruledOut = Set(step.actions.compactMap { action -> CandidateKey? in
                guard case .ruleOut(let digit) = action.action else { return nil }
                return CandidateKey(position: action.position, digit: digit)
            })
            let eliminated = Set(step.reasoning.eliminations.map { CandidateKey(position: $0.position, digit: $0.digit) })
            #expect(eliminated == ruledOut)
        }
    }

    @Test("Each step's reasoning holds in the state just before it")
    func reasoningHoldsBeforeTheStep() {
        var state = BoardState.fromGrid(needsPointing, assumingUniqueSolution: true)
        for step in SolvePathEmitter.emit(from: needsPointing).steps {
            #expect(step.reasoning.inconsistencies(in: state).isEmpty, "\(step.technique.id)")
            state = state.applying(step.hint)
        }
    }

    @Test("A step's hint keeps its technique, actions and reasoning")
    func hintRoundTrips() throws {
        let step = try #require(SolvePathEmitter.emit(from: needsPointing).steps.first { $0.technique.isSingle == false })
        let hint = step.hint
        #expect(hint.technique == step.technique)
        #expect(hint.reasoning == step.reasoning)
        #expect(SolvePathEmitter.SolveStep(hint) == step)
    }

    @Test("Equality is the deduction, not how its reasoning lists cells")
    func equalityIgnoresReasoning() throws {
        let step = try #require(SolvePathEmitter.emit(from: needsPointing).steps.first { $0.technique.isSingle == false })
        let bare = SolvePathEmitter.SolveStep(technique: step.technique, actions: step.actions)
        #expect(bare == step)
        #expect(bare.reasoning.components.isEmpty)
    }

    private struct CandidateKey: Hashable {
        let position: Puzzle.Index
        let digit: Int
    }
}
