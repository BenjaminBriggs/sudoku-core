//
//  PlanFiller.swift
//  SudokuCore
//
//  Puts digits in a setter's plan: the squares chosen for clues before any digits. The fill
//  is a finished puzzle (one solution, solvable by logic up to a level) that keeps the clues
//  already placed and, in order, the technique steps the setter has asked for.
//
//  Random digits almost never give a small plan one solution, so the fill searches the clue
//  digits instead: it changes one at a time and keeps the change while the number of
//  solutions doesn't rise, until it reaches one.
//
import Foundation

public enum PlanFiller {
    /// What a filled plan has to be.
    public struct Request: Sendable, Equatable {
        /// The squares that may hold clues.
        public var plan: Set<Puzzle.Index>
        /// Clues already placed, all inside the plan. Every fill keeps them.
        public var clues: [[Int]]
        /// The hardest level of technique the solve may need.
        public var ceiling: PuzzleDifficulty.Level
        /// Technique steps the solve has to take, in this order, among its other steps.
        public var recorded: [TechniqueInfo]
        /// When set, whole orbits of this symmetry made only of unplaced plan squares may be
        /// left empty, to bring back a recorded step that the full plan skips. `nil` fills
        /// every planned square.
        public var relaxing: Symmetry?

        public init(
            plan: Set<Puzzle.Index>,
            clues: [[Int]] = Solution.empty(),
            ceiling: PuzzleDifficulty.Level = .hard,
            recorded: [TechniqueInfo] = [],
            relaxing: Symmetry? = nil
        ) {
            self.plan = plan
            self.clues = clues
            self.ceiling = ceiling
            self.recorded = recorded
            self.relaxing = relaxing
        }
    }

    /// How hard to search: walks race each other, and each stops at its move limit or when
    /// the time runs out.
    public struct Budget: Sendable, Equatable {
        public var walks: Int
        public var timeout: Duration?
        public var movesPerWalk: Int

        /// Without a timeout, each walk stops at `movesPerWalk`, 50,000 when not given, so a
        /// plan with no fill can't keep the search going forever.
        public init(walks: Int, timeout: Duration?, movesPerWalk: Int? = nil) {
            self.walks = max(1, walks)
            self.timeout = timeout
            self.movesPerWalk = movesPerWalk ?? (timeout == nil ? 50_000 : .max)
        }

        /// One walk per core until `timeout`.
        public static func timed(_ timeout: Duration) -> Budget {
            Budget(walks: ProcessInfo.processInfo.activeProcessorCount, timeout: timeout)
        }

        /// A single walk of at most `moves` moves, however long it takes: the same result for
        /// the same seed every time.
        public static func moves(_ moves: Int) -> Budget {
            Budget(walks: 1, timeout: nil, movesPerWalk: moves)
        }
    }

    /// Two rows of a band, or two columns of a stack, with no planned square.
    public struct SwappableLines: Sendable, Equatable {
        public enum Kind: Sendable, Equatable {
            case rows, columns
        }

        public let kind: Kind
        /// The two lines, from 0.
        public let lines: [Int]
    }

    /// Lines with no planned square that can swap in any solution, so no digits can make the
    /// plan unique. Empty when the plan isn't closed this way.
    public static func swappableLines(in plan: Set<Puzzle.Index>) -> [SwappableLines] {
        var found: [SwappableLines] = []
        for band in 0..<3 {
            let rows = (band * 3..<band * 3 + 3).filter { row in
                (0..<9).allSatisfy { plan.contains(Puzzle.Index(row: row, column: $0)) == false }
            }
            let columns = (band * 3..<band * 3 + 3).filter { column in
                (0..<9).allSatisfy { plan.contains(Puzzle.Index(row: $0, column: column)) == false }
            }
            if rows.count >= 2 { found.append(SwappableLines(kind: .rows, lines: Array(rows.prefix(2)))) }
            if columns.count >= 2 { found.append(SwappableLines(kind: .columns, lines: Array(columns.prefix(2)))) }
        }
        return found
    }

    /// The placed clues are inside the plan and don't clash: a request any fill could meet.
    public static func isConsistent(_ request: Request) -> Bool {
        for position in Puzzle.Index.allIndices where request.clues[position.row][position.column] != 0 {
            if request.plan.contains(position) == false { return false }
        }
        return Validator.hasNoConflicts(in: request.clues)
    }

    /// Whether `grid` is a fill `request` accepts: its clues are inside the plan and keep the
    /// placed ones, it has one solution, the techniques up to the ceiling solve it, and their
    /// path takes the recorded steps in order.
    public static func accepts(_ grid: [[Int]], for request: Request) -> Bool {
        for position in Puzzle.Index.allIndices {
            let value = grid[position.row][position.column]
            let placed = request.clues[position.row][position.column]
            if placed != 0, value != placed { return false }
            if value != 0, request.plan.contains(position) == false { return false }
        }
        guard Validator.countSolutions(of: grid, limit: 2) == 1 else { return false }
        return solvesKeepingRecord(grid, request)
    }

    /// One walk of the search, deterministic for `generator`'s output: `nil` when `maxMoves`
    /// pass, `deadline` does, or the task is cancelled first.
    public static func fill(
        _ request: Request,
        using generator: inout some RandomNumberGenerator,
        maxMoves: Int = 50_000,
        deadline: ContinuousClock.Instant? = nil
    ) -> [[Int]]? {
        guard isConsistent(request) else { return nil }
        var random = SearchRandom(seed: generator.next())
        let fixed = request.clues.flatMap { $0 }
        let open = request.plan.map { $0.row * 9 + $0.column }.filter { fixed[$0] == 0 }.sorted()

        func fresh() -> [Int]? {
            guard let solution = Validator.randomSolution(of: request.clues, using: &random) else { return nil }
            var cells = fixed
            for cell in open { cells[cell] = solution[cell / 9][cell % 9] }
            return cells
        }

        guard var cells = fresh() else { return nil }
        var score = Validator.countSolutions(of: grid(cells), limit: countLimit)
        var stale = 0
        for move in 0..<maxMoves {
            if move % 64 == 0 {
                if Task.isCancelled { return nil }
                if let deadline, ContinuousClock.now >= deadline { return nil }
            }
            if score == 1 {
                let candidate = grid(cells)
                if solvesKeepingRecord(candidate, request) { return candidate }
                if let relaxing = request.relaxing,
                   let relaxed = relax(candidate, request, symmetry: relaxing, using: &random) {
                    return relaxed
                }
                // With every planned square placed, a restart is the same grid again.
                guard open.isEmpty == false, let restart = fresh() else { return nil }
                cells = restart
                score = Validator.countSolutions(of: grid(cells), limit: countLimit)
                stale = 0
                continue
            }
            guard let cell = open.randomElement(using: &random) else { return nil }

            // Another digit for one unplaced square, one its row, column and box don't hold.
            var used = 0
            for peer in peers[cell] where cells[peer] != 0 { used |= 1 << (cells[peer] - 1) }
            let allowed = (1...9).filter { $0 != cells[cell] && used & (1 << ($0 - 1)) == 0 }
            if let value = allowed.randomElement(using: &random) {
                var next = cells
                next[cell] = value
                let nextScore = Validator.countSolutions(of: grid(next), limit: countLimit)
                if nextScore >= 1, nextScore <= score {
                    stale = nextScore < score ? 0 : stale + 1
                    cells = next
                    score = nextScore
                } else {
                    stale += 1
                }
            } else {
                stale += 1
            }
            if stale > staleLimit {
                guard let restart = fresh() else { return nil }
                cells = restart
                score = Validator.countSolutions(of: grid(cells), limit: countLimit)
                stale = 0
            }
        }
        return nil
    }

    /// Races the budget's walks, each seeded from `seed`, and returns the first fill found, or
    /// `nil` when every walk runs out.
    public static func fill(_ request: Request, seed: UInt64, budget: Budget) async -> [[Int]]? {
        let deadline = budget.timeout.map { ContinuousClock.now + $0 }
        return await withTaskGroup(of: [[Int]]?.self) { group in
            for walk in 0..<budget.walks {
                group.addTask {
                    var generator = SearchRandom(seed: seed &+ UInt64(walk) &* 0x9E37_79B9_7F4A_7C15)
                    return fill(request, using: &generator, maxMoves: budget.movesPerWalk, deadline: deadline)
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    // MARK: - Internals

    /// The solution count the search follows, capped: beyond it, every grid looks as far away.
    static let countLimit = 64
    /// Moves without the count falling before the walk starts again from new digits.
    static let staleLimit = 400

    static let peers: [[Int]] = (0..<81).map { cell in
        Puzzle.Index(row: cell / 9, column: cell % 9).allNeighbours.map { $0.row * 9 + $0.column }
    }

    static func grid(_ cells: [Int]) -> [[Int]] {
        (0..<9).map { row in Array(cells[(row * 9)..<(row * 9 + 9)]) }
    }

    /// The techniques up to the ceiling solve `grid`, taking the recorded steps in order.
    static func solvesKeepingRecord(_ grid: [[Int]], _ request: Request) -> Bool {
        let path = SolvePathEmitter.emit(from: grid, using: ClassicTechniques.upTo(request.ceiling))
        return path.solved && takes(request.recorded, path.steps.map(\.technique))
    }

    /// `recorded` appears in `path` in order, with other steps between.
    static func takes(_ recorded: [TechniqueInfo], _ path: [TechniqueInfo]) -> Bool {
        var next = 0
        for technique in path where next < recorded.count && technique.id == recorded[next].id {
            next += 1
        }
        return next == recorded.count
    }

    /// Leaves whole orbits of unplaced plan squares empty, in random order, while the grid
    /// stays unique and solvable, until the recorded steps are back on its path. Taking clues
    /// out never gives the solve a shortcut, so it can only bring a skipped step back.
    static func relax(
        _ grid: [[Int]],
        _ request: Request,
        symmetry: Symmetry,
        using random: inout SearchRandom
    ) -> [[Int]]? {
        var current = grid
        let orbits = symmetry.orbits.filter { orbit in
            orbit.contains { grid[$0.row][$0.column] != 0 }
                && orbit.allSatisfy { request.clues[$0.row][$0.column] == 0 }
        }
        for orbit in orbits.shuffled(using: &random) {
            if Task.isCancelled { return nil }
            var thinner = current
            for position in orbit { thinner[position.row][position.column] = 0 }
            guard Validator.countSolutions(of: thinner, limit: 2) == 1 else { continue }
            let path = SolvePathEmitter.emit(from: thinner, using: ClassicTechniques.upTo(request.ceiling))
            guard path.solved else { continue }
            current = thinner
            if takes(request.recorded, path.steps.map(\.technique)) { return current }
        }
        return nil
    }
}
