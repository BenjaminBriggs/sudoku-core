//
//  SolveUtilities.swift
//  SudokuCore
//
//  Shared utilities for human-style solving steps.
//

import Foundation

extension BoardState {
    /// Build a BoardState from a 9x9 grid, initializing candidates via Validator
    /// and applying any constraint pruning.
    public static func fromGrid(
        _ grid: [[Int]], constraints: [AnyConstraint] = []
    ) -> BoardState {
        var options = Validator.validOptions(for: grid)
        var state = BoardState(
            grid: grid,
            pencilMarks: options,
            validOptions: options,
            constraints: constraints
        )
        if constraints.isEmpty == false {
            for constraint in constraints {
                constraint.base.prune(candidates: &options, in: state)
            }
            state.pencilMarks = options
            state.validOptions = options
        }
        return state
    }

    /// True when every cell is non-zero and there are no conflicts.
    public var isSolved: Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 { return false }
            }
        }
        return Validator.hasNoConflicts(in: grid)
    }

    /// Apply a hint's actions to produce the next BoardState, recalculating candidates.
    public func applying(_ hint: HintStep) -> BoardState {
        var newGrid = self.grid
        var newPencilMarks = self.pencilMarks
        var gridChanged = false

        for action in hint.actions {
            switch action.action {
            case .solveAs(let value):
                newGrid[action.position.row][action.position.column] = value
                newPencilMarks[action.position.row][action.position.column] = []
                gridChanged = true
            case .ruleOut(let value):
                newPencilMarks[action.position.row][action.position.column].remove(value)
            case .pencilIn(_):
                break
            case .clear:
                newGrid[action.position.row][action.position.column] = 0
                gridChanged = true
            }
        }

        // Elimination-only hints leave the grid untouched, so the valid options
        // derived from it are unchanged — skip the full recompute.
        var validOptions = gridChanged ? Validator.validOptions(for: newGrid) : self.validOptions
        if gridChanged && self.constraints.isEmpty == false {
            let snapshot = BoardState(
                grid: newGrid,
                pencilMarks: validOptions,
                validOptions: validOptions,
                solution: self.solution,
                constraints: self.constraints
            )
            for constraint in self.constraints {
                constraint.base.prune(candidates: &validOptions, in: snapshot)
            }
        }
        var merged = newPencilMarks
        for row in 0..<9 {
            for col in 0..<9 {
                merged[row][col] = merged[row][col].intersection(validOptions[row][col])
            }
        }

        return BoardState(
            grid: newGrid,
            pencilMarks: merged,
            validOptions: validOptions,
            solution: self.solution,
            constraints: self.constraints
        )
    }
}

extension HintFinder {
    /// Return the first available hint scanning techniques from easiest to hardest.
    ///
    /// `techniques` defaults to the classic set; variant modules append their own
    /// (e.g. `ClassicTechniques.all + KillerSudoku.techniques`). The array is
    /// stable-sorted by difficulty, so callers compose by concatenation.
    public static func firstHint(
        in state: BoardState,
        using techniques: [any HintTechnique] = ClassicTechniques.all
    ) -> HintStep? {
        for technique in techniques.sorted(by: { $0.info.difficulty < $1.info.difficulty }) {
            if let hint = technique.findHint(in: state) {
                return hint
            }
        }
        return nil
    }
}

