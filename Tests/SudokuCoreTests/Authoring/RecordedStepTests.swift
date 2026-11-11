//
//  RecordedStepTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct RecordedStepTests {
    /// Solved by singles and Pointing.
    let puzzle: [[Int]] = Solution.cells(
        from: "020608000580009700000040000370000500600000004008000013000020000009800036000306090"
    )

    var path: [SolvePathEmitter.SolveStep] { SolvePathEmitter.emit(from: puzzle).steps }

    func pointing() throws -> (index: Int, step: SolvePathEmitter.SolveStep) {
        let steps = path
        let index = try #require(steps.firstIndex { $0.technique == .lockedCandidatesPointing })
        return (index, steps[index])
    }

    @Test func aRecordedStepTakesTheDeductionsDigitsAndSquares() throws {
        let (_, step) = try pointing()
        let recorded = RecordedStep(step)
        #expect(recorded.technique == .lockedCandidatesPointing)
        #expect(recorded.digits == step.reasoning.focusDigits.sorted())
        #expect(recorded.digits.isEmpty == false)
        for action in step.actions { #expect(recorded.squares.contains(action.position)) }
        #expect(recorded.squares.count > step.actions.count)
    }

    @Test func theSameStepMatches() throws {
        let (_, step) = try pointing()
        #expect(RecordedStep(step).matches(step, by: .deduction))
        #expect(RecordedStep(step).matches(step, by: .technique))
    }

    @Test func anotherDigitOnlyMatchesByTechnique() throws {
        let (_, step) = try pointing()
        let original = RecordedStep(step)
        let other = RecordedStep(technique: original.technique, digits: [original.digits[0] % 9 + 1], squares: original.squares)
        #expect(other.matches(step, by: .deduction) == false)
        #expect(other.matches(step, by: .technique))
    }

    @Test func farawaySquaresDontMatch() throws {
        let (_, step) = try pointing()
        let original = RecordedStep(step)
        let elsewhere = Set(Puzzle.Index.allIndices).subtracting(original.squares).prefix(3)
        let other = RecordedStep(technique: original.technique, digits: original.digits, squares: Set(elsewhere))
        #expect(other.matches(step, by: .deduction) == false)
    }

    @Test func emptyDigitsAndSquaresMatchAny() throws {
        let (_, step) = try pointing()
        #expect(RecordedStep(technique: .lockedCandidatesPointing).matches(step, by: .deduction))
        #expect(RecordedStep(technique: .xWing).matches(step, by: .deduction) == false)
    }

    @Test func positionsFollowTheOrder() throws {
        let steps = path
        let (index, step) = try pointing()
        let single = RecordedStep(steps[0])
        #expect(RecordedStep.positions(of: [single, RecordedStep(step)], in: steps, by: .deduction)?.last == index)
        #expect(RecordedStep.positions(of: [RecordedStep(technique: .xWing)], in: steps, by: .deduction) == nil)
        #expect(RecordedStep.positions(of: [], in: steps, by: .deduction) == [])
    }

    @Test func aRecordedStepRoundTrips() throws {
        let (_, step) = try pointing()
        let recorded = RecordedStep(step)
        let decoded = try JSONDecoder().decode(RecordedStep.self, from: JSONEncoder().encode(recorded))
        #expect(decoded == recorded)
    }
}
