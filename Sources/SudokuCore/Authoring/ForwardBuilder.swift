//
//  ForwardBuilder.swift
//  SudokuCore
//
//  Setting a puzzle forwards, as hand setters do: choose the squares for clues first, then
//  give them digits one at a time, each chosen for the deduction it lets the solver make
//  next. The setter can record a step's technique; the finished puzzle's solve has to take
//  every recorded step, in order.
//
//  A clue placed later usually gives the solver a shortcut past an earlier step, so the
//  builder always holds a witness: a finished puzzle that keeps every clue placed so far and
//  every recorded step. A step is only taken when a witness survives it, and finishing the
//  puzzle is taking the witness.
//
import Foundation

public struct ForwardBuilder: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// The hardest level of technique the puzzle may need.
        public var ceiling: PuzzleDifficulty.Level
        /// When set, the finished puzzle may leave out whole orbits of this symmetry that hold
        /// no placed clue, to keep a recorded step the full plan would skip. `nil` keeps every
        /// planned square.
        public var relaxing: Symmetry?
        /// How closely the finished puzzle's solve has to match each recorded step.
        public var matching: RecordedStep.Matching

        public init(
            ceiling: PuzzleDifficulty.Level = .hard,
            relaxing: Symmetry? = .rotational180,
            matching: RecordedStep.Matching = .deduction
        ) {
            self.ceiling = ceiling
            self.relaxing = relaxing
            self.matching = matching
        }
    }

    /// What one more clue would do.
    public struct Option: Sendable, Identifiable {
        public let position: Puzzle.Index
        public let value: Int
        /// The steps logic takes once the clue is in, up to the ceiling, until it stalls.
        public let steps: [SolvePathEmitter.SolveStep]
        /// The hardest technique beyond singles among `steps`, by level then solve order;
        /// `nil` when the clue leads to singles at most.
        public let technique: TechniqueInfo?
        /// Squares logic fills after the clue, not counting the clue itself.
        public let solvedSquares: Int
        /// Unplaced plan squares logic fills. They stay clues, with digits the solver could
        /// already work out.
        public let forcedPlanSquares: Int
        /// Unplaced plan squares that see a square the new technique steps use. A later clue
        /// there is the likeliest to give the solver a way around them.
        public let exposure: Int
        /// The clue's digit is the witness's, so placing it quietly keeps the witness.
        public let matchesWitness: Bool
        /// What logic knows once the clue is in and `steps` have run.
        public let state: BoardState
        /// The clue placed, before any of `steps`.
        public let start: BoardState
        /// The logic grid the option was worked out from: an option only applies to the
        /// builder that offered it.
        let basis: [[Int]]

        public var id: Int { (position.row * 9 + position.column) * 10 + value }

        /// Where `technique` first appears in `steps`.
        public var techniqueStepIndex: Int? {
            guard let technique else { return nil }
            return steps.firstIndex { $0.technique == technique }
        }

        /// The step that uses `technique`, as a hint to explain or show on the board.
        public var techniqueHint: HintStep? {
            techniqueStepIndex.map { steps[$0].hint }
        }

        /// What the solver knows just before `steps[index]`: the clue placed and the steps
        /// before it taken. The grid and candidates a step's explanation refers to.
        public func state(before index: Int) -> BoardState {
            steps.prefix(max(0, min(index, steps.count))).reduce(start) { $0.applying($1.hint) }
        }
    }

    public let plan: Set<Puzzle.Index>
    public let configuration: Configuration
    /// The setter's clues so far.
    public private(set) var clues: [[Int]]
    /// The technique steps the setter recorded, in order.
    public private(set) var recorded: [RecordedStep]
    /// A finished puzzle that keeps every clue and recorded step, once one is found.
    public private(set) var witness: [[Int]]?
    /// What logic up to the ceiling knows from the clues.
    public private(set) var state: BoardState

    /// `nil` when a clue lies outside the plan or the clues clash.
    public init?(
        plan: Set<Puzzle.Index>,
        clues: [[Int]] = Solution.empty(),
        recorded: [RecordedStep] = [],
        configuration: Configuration = Configuration()
    ) {
        guard PlanFiller.isConsistent(PlanFiller.Request(plan: plan, clues: clues)) else { return nil }
        self.plan = plan
        self.configuration = configuration
        self.clues = clues
        self.recorded = recorded
        self.witness = nil
        self.state = Self.logic(from: BoardState.fromGrid(clues), ceiling: configuration.ceiling).finalState
    }

    /// Planned squares with no clue that logic hasn't filled yet.
    public var openSquares: [Puzzle.Index] {
        plan.filter { state.grid[$0.row][$0.column] == 0 }
            .sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    /// The clues the puzzle shows so far: the setter's, and planned squares logic has filled.
    public var knownClues: [[Int]] {
        var known = clues
        for position in plan where known[position.row][position.column] == 0 {
            known[position.row][position.column] = state.grid[position.row][position.column]
        }
        return known
    }

    /// What a fill of the plan has to be.
    public var fillRequest: PlanFiller.Request {
        PlanFiller.Request(
            plan: plan,
            clues: clues,
            ceiling: configuration.ceiling,
            recorded: recorded,
            matching: configuration.matching,
            relaxing: configuration.relaxing
        )
    }

    /// The witness's solution, when there's a witness.
    public var witnessSolution: Solution? {
        guard let witness, case .unique(let solution) = Validator.solutionCount(of: witness) else { return nil }
        return solution
    }

    // MARK: - Options

    /// Every digit `position` can take while the clues keep a solution, with what logic does
    /// next. Empty for a square outside the plan or already filled; stops early, with what it
    /// has, when the task is cancelled.
    public func options(at position: Puzzle.Index) -> [Option] {
        options(at: position, open: Set(openSquares), witnessSolution: witnessSolution)
    }

    /// ``options(at:)`` for every open square, worked out in parallel. Stops early, with what
    /// it has, when the task is cancelled.
    public func options() async -> [Option] {
        let open = Set(openSquares)
        let solution = witnessSolution
        return await withTaskGroup(of: [Option].self) { group in
            for position in open {
                group.addTask { options(at: position, open: open, witnessSolution: solution) }
            }
            var all: [Option] = []
            for await found in group { all += found }
            return all.sorted { $0.id < $1.id }
        }
    }

    private func options(at position: Puzzle.Index, open: Set<Puzzle.Index>, witnessSolution solution: Solution?) -> [Option] {
        guard plan.contains(position), state.grid[position.row][position.column] == 0 else { return [] }
        let filledBefore = Self.filled(state)
        var found: [Option] = []
        for value in state.pencilMarks[position.row][position.column].sorted() {
            if Task.isCancelled { break }
            var trial = state.grid
            trial[position.row][position.column] = value
            guard Validator.hasSolution(trial, nodeLimit: Self.feasibilityNodes) != false else { continue }
            let start = Self.placing(value, at: position, in: state)
            let path = Self.logic(from: start, ceiling: configuration.ceiling)
            let after = path.finalState
            guard Self.isDeadEnd(after) == false else { continue }
            let technique = path.steps.map(\.technique).filter { $0.isSingle == false }
                .max { ($0.level, $0.difficulty) < ($1.level, $1.difficulty) }
            let footprint = Self.footprint(of: path.steps.filter { $0.technique.isSingle == false })
            let stillOpen = open.subtracting([position]).filter { after.grid[$0.row][$0.column] == 0 }
            found.append(Option(
                position: position,
                value: value,
                steps: path.steps,
                technique: technique,
                solvedSquares: Self.filled(after) - filledBefore - 1,
                forcedPlanSquares: open.count - 1 - stillOpen.count,
                exposure: stillOpen.filter { square in
                    footprint.contains(square) || square.allNeighbours.contains(where: footprint.contains)
                }.count,
                matchesWitness: solution?[position.row][position.column] == value,
                state: after,
                start: start,
                basis: state.grid
            ))
        }
        return found
    }

    // MARK: - Steps

    /// The builder after `option`, with its technique recorded, and a witness that keeps the
    /// new step. `nil` when the option came from another builder, the clues alone already
    /// skip the recorded steps, or the search runs out of `budget` before finding a witness.
    public func recording(_ option: Option, seed: UInt64, budget: PlanFiller.Budget) async -> ForwardBuilder? {
        guard option.basis == state.grid else { return nil }
        var next = applying(option)
        if let index = option.techniqueStepIndex { next.recorded.append(RecordedStep(option.steps[index])) }
        guard next.knownCluesKeepRecord else { return nil }
        return await next.withWitness(seed: seed, budget: budget, near: witness)
    }

    /// The builder after `value` goes in `position`, recording nothing. The witness stays when
    /// it has the same digit there; otherwise it's searched for again. `nil` when the digit
    /// breaks the clues, or the search runs out of `budget` before finding a witness.
    public func placing(
        _ value: Int,
        at position: Puzzle.Index,
        seed: UInt64,
        budget: PlanFiller.Budget
    ) async -> ForwardBuilder? {
        guard let option = options(at: position).first(where: { $0.value == value }) else { return nil }
        let next = applying(option)
        guard next.knownCluesKeepRecord else { return nil }
        return await next.withWitness(seed: seed, budget: budget, near: witness)
    }

    /// The builder with a witness: the current one when it still fits, otherwise the first
    /// fill of the plan the search finds within `budget`, starting near `near` (an earlier
    /// witness) when given. `nil` when it finds none.
    public func withWitness(seed: UInt64, budget: PlanFiller.Budget, near: [[Int]]? = nil) async -> ForwardBuilder? {
        var next = self
        if let witness, PlanFiller.accepts(witness, for: fillRequest) { return next }
        // A witness that still holds every clue may only have lost a recorded step to a
        // shortcut: leaving out planned squares can bring it back without a search.
        if let witness, let relaxing = configuration.relaxing {
            var random = SearchRandom(seed: seed)
            if let relaxed = PlanFiller.relax(witness, fillRequest, symmetry: relaxing, using: &random),
               PlanFiller.accepts(relaxed, for: fillRequest) {
                next.witness = relaxed
                return next
            }
        }
        guard PlanFiller.swappableLines(in: plan).isEmpty,
              let found = await PlanFiller.fill(fillRequest, seed: seed, budget: budget, near: near ?? witness),
              PlanFiller.accepts(found, for: fillRequest) else { return nil }
        next.witness = found
        return next
    }

    /// The builder with `witness` as its witness, when the plan accepts it; for restoring a
    /// saved build without searching again.
    public func adopting(_ witness: [[Int]]) -> ForwardBuilder? {
        guard PlanFiller.accepts(witness, for: fillRequest) else { return nil }
        var next = self
        next.witness = witness
        return next
    }

    // MARK: - Internals

    /// Branches a feasibility check may take before calling a digit possible.
    static let feasibilityNodes = 20_000

    /// The clue placed, the witness kept only if it agrees with it.
    private func applying(_ option: Option) -> ForwardBuilder {
        var next = self
        next.clues[option.position.row][option.position.column] = option.value
        next.state = option.state
        if option.matchesWitness == false { next.witness = nil }
        return next
    }

    /// Solving the clues the puzzle shows so far, from scratch, still takes the recorded steps.
    /// Needed but not enough: later clues can still skip them, which the witness rules out.
    private var knownCluesKeepRecord: Bool {
        guard recorded.isEmpty == false else { return true }
        let path = SolvePathEmitter.emit(from: knownClues, using: ClassicTechniques.upTo(configuration.ceiling))
        return PlanFiller.takes(fillRequest, path.steps)
    }

    static func logic(from state: BoardState, ceiling: PuzzleDifficulty.Level) -> SolvePathEmitter.SolvePath {
        SolvePathEmitter.emit(continuingFrom: state, using: ClassicTechniques.upTo(ceiling))
    }

    static func placing(_ value: Int, at position: Puzzle.Index, in state: BoardState) -> BoardState {
        state.applying(HintStep(actions: [HintAction(position: position, solveAs: value)], technique: .nakedSingle))
    }

    static func filled(_ state: BoardState) -> Int {
        state.grid.joined().reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
    }

    /// A square with no candidates left, or a repeated digit: no solution follows.
    static func isDeadEnd(_ state: BoardState) -> Bool {
        for position in Puzzle.Index.allIndices
        where state.grid[position.row][position.column] == 0 && state.pencilMarks[position.row][position.column].isEmpty {
            return true
        }
        return Validator.hasNoConflicts(in: state.grid) == false
    }

    /// The squares technique steps change.
    static func footprint(of steps: [SolvePathEmitter.SolveStep]) -> Set<Puzzle.Index> {
        var squares = Set<Puzzle.Index>()
        for step in steps {
            for action in step.actions { squares.insert(action.position) }
        }
        return squares
    }
}
