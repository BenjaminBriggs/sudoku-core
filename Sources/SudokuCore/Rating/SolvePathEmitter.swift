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
        /// How the step was found, as the hint finder recorded it: what explanations and
        /// board highlights are built from.
        public let reasoning: HintReasoning

        public init(technique: TechniqueInfo, actions: [HintAction], reasoning: HintReasoning = HintReasoning()) {
            self.technique = technique
            self.actions = actions
            self.reasoning = reasoning
            self.eliminations = actions.reduce(0) { acc, a in
                if case .ruleOut = a.action { return acc + 1 } else { return acc }
            }
            self.placements = actions.reduce(0) { acc, a in
                if case .solveAs = a.action { return acc + 1 } else { return acc }
            }
        }

        /// The step a hint takes, keeping its reasoning.
        public init(_ hint: HintStep) {
            self.init(technique: hint.technique, actions: hint.actions, reasoning: hint.reasoning)
        }

        /// The step as a hint, for explaining or showing it.
        public var hint: HintStep {
            HintStep(actions: actions, technique: technique, reasoning: reasoning)
        }

        /// The same deduction: technique and actions. Reasoning is left out because some
        /// techniques list its cells in no fixed order.
        public static func == (lhs: SolveStep, rhs: SolveStep) -> Bool {
            lhs.technique == rhs.technique && lhs.actions == rhs.actions
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

    /// ``emit(from:maxIterations:)`` with only `techniques`, easiest first: the path a solver
    /// who knows just those techniques takes, stalling where they run out.
    public static func emit(
        from initialGrid: [[Int]],
        using techniques: [any HintTechnique],
        maxIterations: Int = 300
    ) -> SolvePath {
        emit(from: initialGrid, maxIterations: maxIterations) { HintFinder.firstHint(in: $0, using: techniques) }
    }

    /// Carries a solve on from `state` with `techniques`, easiest first. The state keeps its own
    /// uniqueness setting, so a state that doesn't assume a unique solution never gets the
    /// uniqueness techniques.
    public static func emit(
        continuingFrom state: BoardState,
        using techniques: [any HintTechnique],
        maxIterations: Int = 300
    ) -> SolvePath {
        solve(from: state, steps: [], iterations: 0, maxIterations: maxIterations) {
            HintFinder.firstHint(in: $0, using: techniques)
        }
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

    /// Two solve paths through the same grid: one taking the first hint `first` finds at every
    /// step, in its order, the other the first hint `second` finds.
    ///
    /// The same paths as emitting each on its own. What a technique finds at a state, and the
    /// state its hint leads to, are worked out once for the two of them, so the second path
    /// costs next to nothing wherever it is at a state the first went through and its order
    /// picks from what the first already tried. Orders that agree for a stretch share all of
    /// it, and paths that part and meet again share from there on.
    ///
    /// A technique is told apart by its id, so the same id in both lists must be the same
    /// technique.
    static func emitPair(
        from initialGrid: [[Int]],
        first: [any HintTechnique],
        second: [any HintTechnique],
        maxIterations: Int = 300
    ) -> (first: SolvePath, second: SolvePath) {
        let start = start(initialGrid)
        var memo = SolveMemo()
        let firstPath = solve(from: start, using: first, maxIterations: maxIterations, memo: &memo)
        let secondPath = solve(from: start, using: second, maxIterations: maxIterations, memo: &memo)
        return (firstPath, secondPath)
    }

    /// ``solve(from:steps:iterations:maxIterations:nextHint:)`` taking the first hint
    /// `techniques` find at every step, in their order, and remembering in `memo` what it
    /// works out.
    private static func solve(
        from start: BoardState,
        using techniques: [any HintTechnique],
        maxIterations: Int,
        memo: inout SolveMemo
    ) -> SolvePath {
        var state = start
        var key = SolveMemo.key(of: start)
        var steps: [SolveStep] = []
        var iterations = 0

        while !state.isSolved {
            iterations += 1
            if iterations > maxIterations { break }

            guard let found = memo.firstHint(of: techniques, in: state, at: key) else { break }
            steps.append(SolveStep(found.hint))
            (state, key) = memo.state(after: found.hint, by: found.technique, from: state, at: key)
        }

        return SolvePath(
            steps: steps,
            solved: state.isSolved,
            finalState: state,
            iterationCount: iterations
        )
    }

    /// What solves have worked out at the states they went through: what each technique found
    /// there, and the state its hint led to. A solve that reaches one of those states again
    /// doesn't work it out a second time.
    ///
    /// For solves that start from the same state: a state is remembered by its digits and
    /// candidates alone, which is all that tells two states of one solve apart.
    private struct SolveMemo {
        /// Each cell's digit, then each cell's candidates as a bitmask.
        typealias Key = [UInt16]

        /// Per state, what each technique tried there found: nil for nothing.
        private var hints: [Key: [TechniqueID: HintStep?]] = [:]
        /// Per state, the state each technique's hint led to.
        private var next: [Key: [TechniqueID: (state: BoardState, key: Key)]] = [:]

        /// The first hint `techniques` find at `state`, in their order, and the technique that
        /// found it.
        mutating func firstHint(
            of techniques: [any HintTechnique], in state: BoardState, at key: Key
        ) -> (technique: TechniqueID, hint: HintStep)? {
            // Looked up once and put back once: the key is long to hash
            var known = hints[key] ?? [:]
            var learned = false
            defer { if learned { hints[key] = known } }
            for technique in techniques {
                let id = technique.info.id
                let hint: HintStep?
                if let remembered = known[id] {
                    hint = remembered
                } else {
                    hint = technique.findHint(in: state)
                    known.updateValue(hint, forKey: id)
                    learned = true
                }
                if let hint { return (id, hint) }
            }
            return nil
        }

        /// `state` with `hint` applied: the hint `technique` found there.
        mutating func state(
            after hint: HintStep, by technique: TechniqueID, from state: BoardState, at key: Key
        ) -> (state: BoardState, key: Key) {
            if let known = next[key]?[technique] { return known }
            let applied = state.applying(hint)
            let result = (applied, Self.key(of: applied))
            next[key, default: [:]][technique] = result
            return result
        }

        static func key(of state: BoardState) -> Key {
            var key: Key = []
            key.reserveCapacity(162)
            for row in state.grid {
                for digit in row { key.append(UInt16(digit)) }
            }
            for row in state.pencilMarks {
                for candidates in row {
                    var mask: UInt16 = 0
                    for digit in candidates { mask |= 1 << UInt16(digit) }
                    key.append(mask)
                }
            }
            return key
        }
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
                        steps: steps + [SolveStep(hint)],
                        iterations: iterations,
                        maxIterations: maxIterations
                    ) { HintFinder.firstHint(in: $0) }
                    guard branch.solved, seen.insert(signature(of: branch)).inserted else { continue }
                    found.append(branch)
                }
            }
            steps.append(SolveStep(chosen))
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
            steps.append(SolveStep(hint))
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
