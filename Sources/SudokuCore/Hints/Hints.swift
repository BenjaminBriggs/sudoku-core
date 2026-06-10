//
//  Hints.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation

public struct HintAction: Sendable {
    public enum ActionType: Sendable {
        case solveAs(Int)
        case ruleOut(Int)
        case pencilIn(Int)
        case clear
    }
    public let position: Puzzle.Index
    public let action: ActionType
    public init(
        position: Puzzle.Index,
        solveAs: Int
    ) {
        self.position = position
        self.action = .solveAs(solveAs)
    }

    public init(
        position: Puzzle.Index,
        ruleOut: Int
    ) {
        self.position = position
        self.action = .ruleOut(ruleOut)
    }

    public init(
        position: Puzzle.Index,
        pencilIn: Int
    ) {
        self.position = position
        self.action = .pencilIn(pencilIn)
    }

    public init(
        clearPosition position: Puzzle.Index
    ) {
        self.position = position
        self.action = .clear
    }

    public var debugDescription: String {
        switch action {
        case .solveAs(let solveAs):
            return "Hint add \(solveAs) at \(position.description)"
        case .ruleOut(let ruleOut):
            return "Hint remove \(ruleOut) at \(position.description)"
        case .pencilIn(let pencilIn):
            return "Hint pencil \(pencilIn) at \(position.description)"
        case .clear:
            return "Hint clear at \(position.description)"
        }
    }
}

/// Example struct for a single deduction hint.
public struct HintStep: CustomDebugStringConvertible, Sendable {
    public let actions: [HintAction]

    /// The technique used for this deduction.
    public let technique: TechniqueInfo

    /// Structured, machine-readable record of how this hint was determined.
    ///
    /// Captures the logical premises of the deduction so the app can validate, re-present,
    /// or generatively explain the hint. Presentation (the human-facing explanation) is built
    /// from this, outside core.
    public let reasoning: HintReasoning

    public var debugDescription: String {
        "Hint(\(technique.id.rawValue), \(actions))"
    }

    public init(
        actions: [HintAction],
        technique: TechniqueInfo,
        reasoning: HintReasoning = HintReasoning()
    ) {
        self.actions = actions
        self.technique = technique
        self.reasoning = reasoning
    }
}
