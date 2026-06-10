//
//  HintReasoning.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 10/06/2026.
//
import Foundation

/// Structured, machine-readable record of *how* a hint was determined.
///
/// This is deliberately distinct from `HintStep.explanation`, which is pre-rendered
/// human-facing text. `HintReasoning` captures the logical premises of a deduction —
/// the digit(s) it is built around, the units involved, the labelled groups of cells
/// that play a structural role, and the placements/eliminations it licenses.
///
/// It exists for three reasons:
/// 1. **Debugging** — `inconsistencies(in:)` can check the recorded premises still hold
///    against a live board, so we can tell whether a hint is applicable to the current state.
/// 2. **Decoupling** — it lets explanation *presentation* move into the app while the
///    *logic* stays in core.
/// 3. **Generative explanations** — it is a compact, `Codable` set of premises that can
///    seed a Foundation Model prompt for tailored, follow-up-capable explanations.
public struct HintReasoning: Sendable, Codable, Equatable {
    /// The digit(s) the pattern is built around — e.g. the fish digit, the subset digits,
    /// the placed value, or the eliminated value.
    public let focusDigits: [Int]

    /// The units (rows / columns / houses) that participate in the deduction.
    public let units: [SudokuUnit]

    /// Labelled groups of cells that play a structural role in the deduction.
    public let components: [HintComponent]

    /// Candidate placements this deduction licenses (mirrors `.solveAs` actions).
    public let placements: [CandidateRef]

    /// Candidate eliminations this deduction licenses (mirrors `.ruleOut` actions).
    public let eliminations: [CandidateRef]

    public init(
        focusDigits: [Int] = [],
        units: [SudokuUnit] = [],
        components: [HintComponent] = [],
        placements: [CandidateRef] = [],
        eliminations: [CandidateRef] = []
    ) {
        self.focusDigits = focusDigits
        self.units = units
        self.components = components
        self.placements = placements
        self.eliminations = eliminations
    }
}

/// A labelled group of cells within a `HintReasoning`.
public struct HintComponent: Sendable, Codable, Equatable {
    /// The structural role a group of cells plays in a deduction.
    public enum Role: String, Sendable, Codable {
        /// The cell(s) the deduction solves (e.g. the naked/hidden single cell).
        case subject
        /// Already-known cells that force the deduction (e.g. peers of a naked single).
        case constraint
        /// The cells forming a naked or hidden subset.
        case subset
        /// A wing pivot cell.
        case pivot
        /// Wing pincer cells, or the "roof"/"tip" cells of single-digit chains.
        case wing
        /// The base set of a fish / the defining cells of a single-digit pattern.
        case base
        /// The cover set of a fish.
        case cover
        /// Fin cells of a finned fish.
        case fin
        /// Cells losing a candidate as a result of the deduction.
        case eliminated
    }

    public let role: Role
    public let cells: [CellFact]
    /// The unit this component lives in, when meaningful (e.g. the subset's unit).
    public let unit: SudokuUnit?

    public init(role: Role, cells: [CellFact], unit: SudokuUnit? = nil) {
        self.role = role
        self.cells = cells
        self.unit = unit
    }
}

/// A single cell's relevant facts at the moment a hint was determined.
public struct CellFact: Sendable, Codable, Equatable {
    public let position: Puzzle.Index
    /// A placed/known value at this cell, if the cell is filled and relevant.
    public let value: Int?
    /// Candidates at this cell relevant to the deduction (usually the cell's pencil marks).
    public let candidates: Set<Int>

    public init(position: Puzzle.Index, value: Int? = nil, candidates: Set<Int> = []) {
        self.position = position
        self.value = value
        self.candidates = candidates
    }

    /// Snapshots a cell from the board: captures its placed value if filled, otherwise its pencil marks.
    public init(_ position: Puzzle.Index, in state: BoardState) {
        let value = state.grid[position.row][position.column]
        self.init(
            position: position,
            value: value == 0 ? nil : value,
            candidates: value == 0 ? state.pencilMarks[position.row][position.column] : []
        )
    }
}

/// A (cell, digit) pair — used for placements and eliminations.
public struct CandidateRef: Sendable, Codable, Equatable {
    public let position: Puzzle.Index
    public let digit: Int

    public init(position: Puzzle.Index, digit: Int) {
        self.position = position
        self.digit = digit
    }
}

// MARK: - Construction Helpers

extension HintComponent {
    /// Builds a component, snapshotting each cell's facts from the board.
    static func make<S: Sequence>(
        _ role: Role,
        _ positions: S,
        in state: BoardState,
        unit: SudokuUnit? = nil
    ) -> HintComponent where S.Element == Puzzle.Index {
        HintComponent(role: role, cells: positions.map { CellFact($0, in: state) }, unit: unit)
    }

    /// Builds a component where every cell carries the same fixed candidate set
    /// (useful for single-digit patterns where only the focus digit is relevant).
    static func make<S: Sequence>(
        _ role: Role,
        _ positions: S,
        candidates: Set<Int>,
        unit: SudokuUnit? = nil
    ) -> HintComponent where S.Element == Puzzle.Index {
        HintComponent(
            role: role,
            cells: positions.map { CellFact(position: $0, candidates: candidates) },
            unit: unit
        )
    }
}

extension HintReasoning {
    /// Builds a `HintReasoning`, deriving `placements`/`eliminations` directly from `actions`
    /// so they stay in lockstep with what the hint applies. Empty components are dropped.
    static func make(
        actions: [HintAction],
        focusDigits: [Int],
        units: [SudokuUnit] = [],
        components: [HintComponent]
    ) -> HintReasoning {
        var placements: [CandidateRef] = []
        var eliminations: [CandidateRef] = []
        for action in actions {
            switch action.action {
            case .solveAs(let digit):
                placements.append(CandidateRef(position: action.position, digit: digit))
            case .ruleOut(let digit):
                eliminations.append(CandidateRef(position: action.position, digit: digit))
            case .pencilIn, .clear:
                break
            }
        }
        return HintReasoning(
            focusDigits: focusDigits,
            units: units,
            components: components.filter { $0.cells.isEmpty == false },
            placements: placements,
            eliminations: eliminations
        )
    }
}

// MARK: - Validation

extension HintReasoning {
    /// Checks the recorded premises against a board state and returns any discrepancies.
    ///
    /// An empty result means the reasoning is consistent with `state` — i.e. the hint is
    /// still applicable. A non-empty result lists human-readable problems, which is useful
    /// both for debugging hint generation and for deciding whether a stored hint is stale.
    ///
    /// - Parameter state: The board state to validate against.
    /// - Returns: A list of discrepancies, empty if the reasoning holds.
    public func inconsistencies(in state: BoardState) -> [String] {
        var problems: [String] = []

        for placement in placements {
            let current = state.grid[placement.position.row][placement.position.column]
            if current != 0 {
                problems.append(
                    "Placement of \(placement.digit) at \(placement.position) targets a filled cell (value \(current))."
                )
            }
        }

        for elimination in eliminations {
            let candidates = state.pencilMarks[elimination.position.row][elimination.position.column]
            if candidates.contains(elimination.digit) == false {
                problems.append(
                    "Elimination of \(elimination.digit) at \(elimination.position) but it is not a current candidate."
                )
            }
        }

        for component in components {
            for fact in component.cells {
                let row = fact.position.row
                let column = fact.position.column
                if let value = fact.value {
                    if state.grid[row][column] != value {
                        problems.append(
                            "\(component.role.rawValue) cell \(fact.position) expected value \(value) but board has \(state.grid[row][column])."
                        )
                    }
                } else if fact.candidates.isEmpty == false {
                    let current = state.pencilMarks[row][column]
                    if fact.candidates.isSubset(of: current) == false {
                        problems.append(
                            "\(component.role.rawValue) cell \(fact.position) candidates \(fact.candidates.sorted()) are not all present in \(current.sorted())."
                        )
                    }
                }
            }
        }

        return problems
    }
}
