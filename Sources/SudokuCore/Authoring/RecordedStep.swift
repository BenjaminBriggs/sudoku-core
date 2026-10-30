//
//  RecordedStep.swift
//  SudokuCore
//
//  A technique step a setter chose while building forwards. The finished puzzle's solve has
//  to take it: the same deduction, not just a step of the same technique somewhere else.
//
import Foundation

public struct RecordedStep: Sendable, Hashable, Codable {
    /// How strictly a solve step has to match a recorded one.
    public enum Matching: String, Sendable, Codable {
        /// The same technique, about the same digits, on overlapping squares: the setter's
        /// own deduction.
        case deduction
        /// Any step of the same technique.
        case technique
    }

    public let technique: TechniqueInfo
    /// The digits the deduction is about, sorted. Empty matches any.
    public let digits: [Int]
    /// The squares of the deduction's pattern and the squares it changes. Empty matches any.
    public let squares: Set<Puzzle.Index>

    public init(technique: TechniqueInfo, digits: [Int] = [], squares: Set<Puzzle.Index> = []) {
        self.technique = technique
        self.digits = Array(Set(digits)).sorted()
        self.squares = squares
    }

    /// The step as the solve path took it: its focus digits (or, without any, the digits its
    /// actions place or remove), and every square of its reasoning except the already-known
    /// ones that force it, with the squares its actions change.
    public init(_ step: SolvePathEmitter.SolveStep) {
        var digits = step.reasoning.focusDigits
        if digits.isEmpty {
            digits = step.actions.compactMap { action in
                switch action.action {
                case .solveAs(let digit), .ruleOut(let digit): digit
                case .pencilIn, .clear: nil
                }
            }
        }
        var squares = Set(step.actions.map(\.position))
        for component in step.reasoning.components where component.role != .constraint {
            for cell in component.cells { squares.insert(cell.position) }
        }
        self.init(technique: step.technique, digits: digits, squares: squares)
    }

    /// Whether `step` takes this recorded step.
    public func matches(_ step: SolvePathEmitter.SolveStep, by matching: Matching) -> Bool {
        guard step.technique.id == technique.id else { return false }
        guard matching == .deduction else { return true }
        let other = RecordedStep(step)
        if digits.isEmpty == false, other.digits.isEmpty == false, digits != other.digits { return false }
        if squares.isEmpty == false, other.squares.isEmpty == false, squares.isDisjoint(with: other.squares) {
            return false
        }
        return true
    }

    /// Where `steps` take each of `recorded`, in order, with other steps between: the first
    /// matching step for each, after the previous one's. `nil` when one isn't taken.
    public static func positions(
        of recorded: [RecordedStep],
        in steps: [SolvePathEmitter.SolveStep],
        by matching: Matching
    ) -> [Int]? {
        var positions: [Int] = []
        var next = 0
        for step in recorded {
            guard let found = steps[next...].firstIndex(where: { step.matches($0, by: matching) }) else { return nil }
            positions.append(found)
            next = found + 1
        }
        return positions
    }
}
