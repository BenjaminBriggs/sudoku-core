//
//  SolvePathEmitter.swift
//  SudokuCore
//
//  Emits a deterministic, human-style solve path using existing hint techniques.
//

import Foundation

public enum SolvePathEmitter {
    public struct SolveStep: Sendable, Equatable {
        public let technique: TechniqueInfo
        public let actions: [HintAction]
        public let eliminations: Int
        public let placements: Int

        public init(technique: TechniqueInfo, actions: [HintAction]) {
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
    /// based on `ClassicTechniques.all`.
    ///
    /// The uniqueness techniques join in only when the grid has exactly one solution, which
    /// is checked here so every caller rates the same way.
    /// - Parameters:
    ///   - initialGrid: 9x9 puzzle with 0 for empty cells
    ///   - maxIterations: safety cap to avoid infinite loops
    /// - Returns: `SolvePath` with ordered steps and final state
    public static func emit(from initialGrid: [[Int]], maxIterations: Int = 300) -> SolvePath {
        emit(from: initialGrid, maxIterations: maxIterations) { HintFinder.firstHint(in: $0) }
    }

    /// ``emit(from:maxIterations:)``, taking each step from `nextHint` instead of the hint
    /// finder's own order.
    static func emit(
        from initialGrid: [[Int]],
        maxIterations: Int = 300,
        nextHint: (BoardState) -> HintStep?
    ) -> SolvePath {
        solve(from: start(initialGrid), steps: [], iterations: 0, maxIterations: maxIterations, nextHint: nextHint)
    }

    /// Other logical paths through the puzzle.
    ///
    /// The main path takes the easiest technique that applies at every step. At each of its
    /// steps beyond singles, this takes every other technique that applies there instead and
    /// carries on easiest-first, so each alternative differs from the main path in one choice.
    /// Singles are not branched on: whatever order they go in, the same candidates are left
    /// once they run out. Alternatives that stall are left out, and so are ones that use the
    /// same techniques beyond singles as the main path or another alternative. Sorted by the
    /// hardest step's level, then difficulty (points beyond singles), then length.
    ///
    /// Stops early, with what it has, when the task is cancelled.
    public static func alternatives(from initialGrid: [[Int]], maxIterations: Int = 300) -> [SolvePath] {
        var state = start(initialGrid)
        var steps: [SolveStep] = []
        var iterations = 0
        var seen: Set<[TechniqueID]> = []
        var found: [SolvePath] = []

        // Walk the main path, branching at every step beyond singles
        while !state.isSolved {
            iterations += 1
            if iterations > maxIterations || Task.isCancelled { break }
            guard let chosen = HintFinder.firstHint(in: state) else { break }
            if chosen.technique.isSingle == false {
                for hint in HintFinder.hints(in: state) where hint.technique != chosen.technique {
                    if Task.isCancelled { break }
                    let branch = solve(
                        from: state.applying(hint),
                        steps: steps + [SolveStep(technique: hint.technique, actions: hint.actions)],
                        iterations: iterations,
                        maxIterations: maxIterations
                    ) { HintFinder.firstHint(in: $0) }
                    guard branch.solved, seen.insert(signature(of: branch)).inserted else { continue }
                    found.append(branch)
                }
            }
            steps.append(SolveStep(technique: chosen.technique, actions: chosen.actions))
            state = state.applying(chosen)
        }

        let main = signature(of: steps)
        return found
            .filter { signature(of: $0) != main }
            .sorted { rank(of: $0) < rank(of: $1) }
    }

    /// The starting state: candidates from the grid, with the uniqueness techniques turned on
    /// only when the grid has exactly one solution.
    private static func start(_ initialGrid: [[Int]]) -> BoardState {
        let isUnique = Validator.solutionCount(of: initialGrid).isUnique
        return BoardState.fromGrid(initialGrid, assumingUniqueSolution: isUnique)
    }

    /// Applies `nextHint` from `start` until the puzzle is solved, none applies, or the cap is hit.
    private static func solve(
        from start: BoardState,
        steps: [SolveStep],
        iterations: Int,
        maxIterations: Int,
        nextHint: (BoardState) -> HintStep?
    ) -> SolvePath {
        var state = start
        var steps = steps
        var iterations = iterations

        while !state.isSolved {
            iterations += 1
            if iterations > maxIterations { break }

            guard let hint = nextHint(state) else { break }
            steps.append(SolveStep(technique: hint.technique, actions: hint.actions))
            state = state.applying(hint)
        }

        return SolvePath(
            steps: steps,
            solved: state.isSolved,
            finalState: state,
            iterationCount: iterations
        )
    }

    /// The techniques beyond singles, in order: what makes one path differ from another.
    private static func signature(of path: SolvePath) -> [TechniqueID] {
        signature(of: path.steps)
    }

    private static func signature(of steps: [SolveStep]) -> [TechniqueID] {
        steps.map(\.technique).filter { $0.isSingle == false }.map(\.id)
    }

    /// Hardest step's level, then points beyond singles, then length.
    private static func rank(of path: SolvePath) -> (PuzzleDifficulty.Level, Int, Int) {
        let score = ScoreCalculator.compute(from: path)
        return (score.level, score.difficulty, path.steps.count)
    }
}
