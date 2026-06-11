//
//  ConstraintPruning.swift
//  SudokuCore
//
import Foundation

extension BoardState {
    /// Apply constraint pruning repeatedly until the candidates stabilize.
    ///
    /// Each pass rebuilds the snapshot from the current candidates, so a
    /// constraint sees the eliminations made by its peers (and by earlier
    /// passes of itself). Constraints only remove candidates, so the loop is
    /// monotonically decreasing; the pass cap is a defensive backstop against
    /// a misbehaving conformer, not an expected exit.
    static func pruneToFixpoint(
        candidates: inout PencilMarks,
        grid: [[Int]],
        solution: [[Int]]?,
        constraints: [AnyConstraint]
    ) {
        guard constraints.isEmpty == false else { return }

        // 729 = 81 cells × 9 digits: a productive pass removes at least one
        // candidate, so no honest run can need more passes than that.
        var passes = 0
        while passes <= 729 {
            passes += 1
            let snapshot = BoardState(
                grid: grid,
                pencilMarks: candidates,
                validOptions: candidates,
                solution: solution,
                constraints: constraints
            )
            let before = candidates
            for constraint in constraints {
                constraint.base.prune(candidates: &candidates, in: snapshot)
            }
            if candidates == before { return }
        }
        assertionFailure("Constraint pruning failed to converge — a Constraint is adding candidates")
    }
}
