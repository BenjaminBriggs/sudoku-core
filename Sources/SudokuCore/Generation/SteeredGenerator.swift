//
//  SteeredGenerator.swift
//  SudokuCore
//
//  Generation aimed at a level: clues come out of a solution while the puzzle rates too easy,
//  and go back while it rates too hard or needs guessing, until the calculator's own level
//  is the one asked for.
//

import Foundation

/// A puzzle the steered generator found, with the rating that placed it and what it cost.
public struct SteeredPuzzle: Sendable {
    public let puzzle: Puzzle
    public let result: SudokuDifficultyCalculator.DifficultyResult
    /// Whether the calculator's level is the one asked for. Only `false` from a best-effort run.
    public let matchesLevel: Bool
    /// Ratings spent, the generator's main cost.
    public let ratings: Int
}

/// Why the steered generator came back without a puzzle.
public enum SteerMiss: Error, Sendable {
    /// The level wasn't reached within the rating budget.
    case level
    /// The clue count range ruled the level out: the minimal puzzle has too many clues, or
    /// reaching the level needed more or fewer clues than the range allows.
    case givens
    /// The task was cancelled.
    case cancelled
}

extension PuzzleDifficulty.Level {
    /// The scores `SudokuDifficultyCalculator` places at this level.
    public var scoreRange: ClosedRange<Int> {
        switch self {
        case .easy: 0...300
        case .medium: 301...600
        case .hard: 601...1000
        case .expert: 1001...1600
        case .professional: 1601...2000
        case .custom: 2001...Int.max
        }
    }
}

extension SudokuGenerator {
    /// How far below a level's lowest score a minimal puzzle may rate and still be worth
    /// swapping clues on. Measured: a minimal puzzle 250 points short of Expert reaches it
    /// about half the time; further off it rarely does.
    static let climbReach = 300

    /// Creates a puzzle the calculator rates at `level`, never one that needs guessing.
    ///
    /// Removes clues (a whole orbit at a time under `symmetry`) in random order while the
    /// puzzle stays unique, keeping the order. Because each step only removes, the puzzles
    /// along the way nest, and their scores rise with the number of blanks, so a binary search
    /// over that order finds the point where the rating reaches a random score in the level's
    /// range: the rest of the order goes back in. A minimal puzzle still short of the level
    /// is pushed harder by swaps: one removed orbit back, up to two others out, kept when the
    /// rating rises without passing the level or needing guessing.
    ///
    /// - Parameters:
    ///   - level: The calculator level to reach. `.custom` means anything past Master.
    ///   - symmetry: The symmetry the clue layout keeps.
    ///   - solution: The solved grid to take clues from.
    ///   - maxRatings: Bound on ratings, the expensive step, including the search.
    ///   - givens: The number of clues the puzzle may have; `nil` for any. Only puzzles in
    ///     the range are rated, so a range costs nothing and stops early when the minimal
    ///     puzzle already has too many clues.
    ///   - bestEffort: Return the closest puzzle found, with `matchesLevel` false, rather
    ///     than `nil` when the level isn't reached.
    /// - Returns: `nil` when the level isn't reached within `maxRatings` (and not
    ///   `bestEffort`), or when the task is cancelled.
    public static func createPuzzle(
        level: PuzzleDifficulty.Level,
        symmetry: Symmetry = .none,
        givens: ClosedRange<Int>? = nil,
        from solution: [[Int]] = SolutionGenerator.generateRandomSolution(),
        maxRatings: Int = 40,
        bestEffort: Bool = false
    ) -> SteeredPuzzle? {
        try? steerPuzzle(
            level: level, symmetry: symmetry, givens: givens, from: solution,
            maxRatings: maxRatings, bestEffort: bestEffort
        ).get()
    }

    /// ``createPuzzle(level:symmetry:givens:from:maxRatings:bestEffort:)``, saying why when
    /// it finds nothing.
    public static func steerPuzzle(
        level: PuzzleDifficulty.Level,
        symmetry: Symmetry = .none,
        givens: ClosedRange<Int>? = nil,
        from solution: [[Int]] = SolutionGenerator.generateRandomSolution(),
        maxRatings: Int = 40,
        bestEffort: Bool = false
    ) -> Result<SteeredPuzzle, SteerMiss> {
        var steer = Steer(
            solution: solution, symmetry: symmetry, range: level.scoreRange,
            givens: givens ?? 0...81, maxRatings: maxRatings
        )
        let found: Steer.Rated
        switch steer.run() {
        case .success(let rated): found = rated
        case .failure(let miss): return .failure(miss)
        }
        let matches = level.scoreRange.contains(Int(found.result.score))
        guard matches || bestEffort else { return .failure(steer.givensBlocked ? .givens : .level) }
        // Steering rates without the HoDoKu estimate; the puzzle it keeps gets one.
        let result = (try? SudokuDifficultyCalculator.calculateDifficulty(for: found.grid)) ?? found.result
        return .success(SteeredPuzzle(
            puzzle: Puzzle(solution: solution, startingState: found.grid, difficulty: result.puzzleDifficulty),
            result: result,
            matchesLevel: matches,
            ratings: steer.ratings
        ))
    }
}

private struct Steer {
    typealias Rated = (grid: [[Int]], result: SudokuDifficultyCalculator.DifficultyResult)

    let solution: [[Int]]
    let symmetry: Symmetry
    let range: ClosedRange<Int>
    let givens: ClosedRange<Int>
    let maxRatings: Int
    private(set) var ratings = 0
    /// The clue count range stopped the search going where the level was.
    private(set) var givensBlocked = false
    /// The closest acceptable puzzle so far: unique, rated, no guessing.
    private var best: Rated?

    init(solution: [[Int]], symmetry: Symmetry, range: ClosedRange<Int>, givens: ClosedRange<Int>, maxRatings: Int) {
        self.solution = solution
        self.symmetry = symmetry
        self.range = range
        self.givens = givens
        self.maxRatings = maxRatings
    }

    /// The closest puzzle found, or why there's none at all.
    mutating func run() -> Result<Rated, SteerMiss> {
        // Remove orbits to a minimal puzzle, keeping the order they came out in
        var grid = solution
        var removed: [[Puzzle.Index]] = []
        for orbit in symmetry.orbits.shuffled() {
            if Task.isCancelled { return .failure(.cancelled) }
            set(orbit, in: &grid, to: false)
            if Validator.solutionCount(of: grid).isUnique {
                removed.append(orbit)
            } else {
                set(orbit, in: &grid, to: true)
            }
        }

        // Prefix lengths whose puzzles have an allowed number of clues; clues fall as it grows
        var clues = [81]
        for orbit in removed {
            clues.append(clues[clues.count - 1] - orbit.count)
        }
        let shortest = max(1, clues.firstIndex { $0 <= givens.upperBound } ?? Int.max)
        let longest = clues.lastIndex { $0 >= givens.lowerBound } ?? 0
        guard shortest <= longest else {
            givensBlocked = true
            return .failure(.givens)
        }

        // Smallest prefix of the order whose puzzle reaches the target or overshoots
        let target = Int.random(in: range.lowerBound...min(range.upperBound, range.lowerBound + 1000))
        var low = shortest - 1
        var high = longest
        var found: Rated?
        while low < high, ratings < maxRatings {
            if Task.isCancelled { return .failure(.cancelled) }
            let mid = (low + high) / 2
            let candidate = prefix(removed, count: mid + 1)
            guard let result = rate(candidate) else { return best.map { .success($0) } ?? .failure(.level) }
            if result.needsGuessing || Int(result.score) >= target {
                if result.needsGuessing == false, range.contains(Int(result.score)) {
                    found = (candidate, result)
                }
                high = mid
            } else {
                low = mid + 1
            }
        }
        if let found { return .success(found) }
        // Too hard at the most clues allowed, or too easy at the fewest
        if (high == shortest - 1 && shortest > 1) || (low == longest && longest < removed.count) {
            givensBlocked = true
        }

        // Short of the level at the deepest puzzle that rates: swap clues to push it harder
        guard var current = best, Int(current.result.score) >= range.lowerBound - SudokuGenerator.climbReach else {
            return best.map { .success($0) } ?? .failure(givensBlocked ? .givens : .level)
        }
        while ratings < maxRatings, Int(current.result.score) < range.lowerBound {
            if Task.isCancelled { return .failure(.cancelled) }
            guard let swapped = swap(current.grid) else { continue }
            guard givens.contains(clueCount(swapped)) else {
                ratings += 1
                continue
            }
            guard let result = rate(swapped) else { continue }
            if result.needsGuessing == false, Int(result.score) >= Int(current.result.score),
                Int(result.score) <= range.upperBound
            {
                current = (swapped, result)
            }
        }
        return best.map { .success($0) } ?? .failure(.level)
    }

    private func clueCount(_ grid: [[Int]]) -> Int {
        grid.joined().count { $0 != 0 }
    }

    /// The solution with the first `count` orbits of `order` removed.
    private func prefix(_ order: [[Puzzle.Index]], count: Int) -> [[Int]] {
        var grid = solution
        for orbit in order.prefix(count) {
            set(orbit, in: &grid, to: false)
        }
        return grid
    }

    /// One removed orbit back, then up to two given orbits out, keeping a unique solution.
    /// `nil` when nothing could come out, which still costs a try against the budget.
    private mutating func swap(_ grid: [[Int]]) -> [[Int]]? {
        let orbits = symmetry.orbits
        let isGiven = { (orbit: [Puzzle.Index], grid: [[Int]]) in grid[orbit[0].row][orbit[0].column] != 0 }
        // The puzzle being climbed always has at least one orbit out.
        let back = orbits.filter { isGiven($0, grid) == false }.randomElement()!
        var candidate = grid
        set(back, in: &candidate, to: true)
        var taken = 0
        for orbit in orbits.shuffled() where orbit != back && isGiven(orbit, candidate) {
            set(orbit, in: &candidate, to: false)
            if Validator.solutionCount(of: candidate).isUnique {
                taken += 1
                if taken == 2 { break }
            } else {
                set(orbit, in: &candidate, to: true)
            }
        }
        guard taken > 0 else {
            ratings += 1
            return nil
        }
        return candidate
    }

    /// Rates `grid`, counting the rating and keeping it as `best` when it's the closest yet.
    private mutating func rate(_ grid: [[Int]]) -> SudokuDifficultyCalculator.DifficultyResult? {
        ratings += 1
        guard let result = try? SudokuDifficultyCalculator.calculateDifficulty(for: grid, estimatingHoDoKu: false) else { return nil }
        if result.needsGuessing == false {
            let distance = distance(Int(result.score))
            if best.map({ distance < self.distance(Int($0.result.score)) }) ?? true {
                best = (grid, result)
            }
        }
        return result
    }

    private func distance(_ score: Int) -> Int {
        if score < range.lowerBound { return range.lowerBound - score }
        if score > range.upperBound { return score - range.upperBound }
        return 0
    }

    private func set(_ orbit: [Puzzle.Index], in grid: inout [[Int]], to given: Bool) {
        for cell in orbit {
            grid[cell.row][cell.column] = given ? solution[cell.row][cell.column] : 0
        }
    }
}
