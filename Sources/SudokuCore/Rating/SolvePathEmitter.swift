//
//  SolvePathEmitter.swift
//  SudokuCore
//
//  Emits a deterministic, human-style solve path using existing hint techniques.
//

import Foundation

public enum SolvePathEmitter {
    public struct SolveStep: Sendable, Equatable {
        public let technique: HintTechnique
        public let actions: [HintAction]
        public let eliminations: Int
        public let placements: Int

        public init(technique: HintTechnique, actions: [HintAction]) {
            self.technique = technique
            self.actions = actions
            self.eliminations = actions.reduce(0) { acc, a in
                if case .ruleOut = a.action { return acc + 1 } else { return acc }
            }
            self.placements = actions.reduce(0) { acc, a in
                if case .solveAs = a.action { return acc + 1 } else { return acc }
            }
        }
    }

    public struct SolvePath: Sendable, Equatable {
        public let steps: [SolveStep]
        public let solved: Bool
        public let finalState: BoardState
        public let iterationCount: Int
    }

    /// Produce a deterministic solve path by repeatedly applying the first-found hint
    /// based on `HintTechnique.orderedCases`.
    /// - Parameters:
    ///   - initialGrid: 9x9 puzzle with 0 for empty cells
    ///   - maxIterations: safety cap to avoid infinite loops
    /// - Returns: `SolvePath` with ordered steps and final state
    public static func emit(from initialGrid: [[Int]], maxIterations: Int = 300) -> SolvePath {
        var state = BoardState.fromGrid(initialGrid)
        var steps: [SolveStep] = []
        var iterations = 0

        while !state.isSolved {
            iterations += 1
            if iterations > maxIterations { break }

            guard let hint = HintFinder.firstHint(in: state) else { break }
            let step = SolveStep(
                technique: hint.technique,
                actions: hint.actions
            )
            steps.append(step)
            state = state.applying(hint)
        }

        return SolvePath(
            steps: steps,
            solved: state.isSolved,
            finalState: state,
            iterationCount: iterations
        )
    }

    // Internals moved to shared utilities (SolveUtilities.swift)
}
