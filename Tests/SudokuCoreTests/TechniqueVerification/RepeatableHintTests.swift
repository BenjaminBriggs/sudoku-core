//
//  RepeatableHintTests.swift
//  SudokuCore
//
//  A hint found twice at the same state has to be the same value, order and all. Callers
//  compare hints to tell whether a step is the one they already showed or counted, and a
//  finder that walks a `Set` lists its cells differently from one find to the next.
//
import Testing
@testable import SudokuCore

@Suite("Repeatable hints")
struct RepeatableHintTests {
    @Test("Every technique finds an equal hint each time it looks", arguments: CorpusPuzzle.selected)
    func hintsAreEqualWhenFoundAgain(_ puzzle: CorpusPuzzle) {
        // The puzzle's states and each with candidates thinned, which is where most techniques
        // have something to find
        let states = TechniqueVerificationTests.states(for: puzzle)
        for technique in ClassicTechniques.all {
            for (index, state) in states.enumerated() where index % 3 == 0 {
                guard let first = technique.findHint(in: state) else { continue }
                // A set's order changes from one set to the next, not on every find, so look
                // a few times
                for _ in 0..<3 {
                    let again = technique.findHint(in: state)
                    #expect(
                        again?.reasoning == first.reasoning,
                        "\(technique.info.id) lists its reasoning differently at state \(index)")
                    #expect(
                        again.map { SolvePathEmitter.SolveStep($0) } == SolvePathEmitter.SolveStep(first),
                        "\(technique.info.id) lists its actions differently at state \(index)")
                }
            }
        }
    }

    @Test("A solve path is equal each time it's emitted", arguments: CorpusPuzzle.selected)
    func pathsAreEqualWhenEmittedAgain(_ puzzle: CorpusPuzzle) {
        let first = SolvePathEmitter.emit(from: puzzle.startingState)
        let again = SolvePathEmitter.emit(from: puzzle.startingState)
        #expect(first == again)
        #expect(first.steps.map(\.reasoning) == again.steps.map(\.reasoning))
    }

    @Test("Cells handed over as a set are listed by row, then column")
    func setsAreListedInGridOrder() {
        let cells: Set<Puzzle.Index> = [
            Puzzle.Index(row: 8, column: 0), Puzzle.Index(row: 0, column: 8), Puzzle.Index(row: 4, column: 4),
            Puzzle.Index(row: 0, column: 1), Puzzle.Index(row: 4, column: 2),
        ]
        let expected = [
            Puzzle.Index(row: 0, column: 1), Puzzle.Index(row: 0, column: 8), Puzzle.Index(row: 4, column: 2),
            Puzzle.Index(row: 4, column: 4), Puzzle.Index(row: 8, column: 0),
        ]
        #expect(cells.inGridOrder == expected)
        #expect(HintComponent.eliminated(cells, candidates: [5]).cells.map(\.position) == expected)

        // Cells handed over in an order keep it
        let reversed = Array(expected.reversed())
        #expect(HintComponent.wing(reversed, candidates: [5]).cells.map(\.position) == reversed)
    }
}
