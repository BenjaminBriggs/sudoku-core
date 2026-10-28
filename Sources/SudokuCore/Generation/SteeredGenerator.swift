//
//  SteeredGenerator.swift
//  SudokuCore
//
//  Generation aimed at a level: clues come out of a solution while the puzzle rates too easy,
//  and go back while it rates too hard or needs guessing, until the calculator's own level
//  is the one asked for and the singles are in the level's tedium window.
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
    /// The tedium (singles points, 4 a naked and 14 a hidden one) the generator aims for at
    /// this level: enough blanks to be a puzzle, not so many that the singles become the
    /// puzzle. Beginner is the lighter window, since singles are all it has; 150 to 300 is
    /// roughly 30 to 45 blanks, mostly naked singles. A level is met by its hardest step,
    /// so a puzzle outside the window is still at the level, just a poorer one.
    public var tediumRange: ClosedRange<Int> {
        switch self {
        case .easy: 150...300
        default: 250...450
        }
    }
}

extension SudokuGenerator {
    /// Creates a puzzle the calculator rates at `level`, never one that needs guessing.
    ///
    /// Removes clues (a whole orbit at a time under `symmetry`) in random order while the
    /// puzzle stays unique, keeping the order. Because each step only removes, the puzzles
    /// along the way nest, and their level and tedium rise with the number of blanks, so
    /// binary searches over that order find where the rating enters the level (and the level's
    /// ``PuzzleDifficulty/Level/tediumRange``) and where it leaves either; a random point
    /// between is the puzzle, and the rest of the order goes back in. A minimal puzzle still
    /// one level short is pushed harder by swaps: one removed orbit back, up to two others
    /// out, kept when the rating rises without passing the level or needing guessing.
    ///
    /// - Parameters:
    ///   - level: The calculator level to reach. `.custom` can't be reached: no technique
    ///     gives it, so the run spends its budget and returns `nil` or the best effort.
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
            solution: solution, symmetry: symmetry, level: level,
            givens: givens ?? 0...81, maxRatings: maxRatings
        )
        let found: Steer.Rated
        switch steer.run() {
        case .success(let rated): found = rated
        case .failure(let miss): return .failure(miss)
        }
        let matches = found.result.level == level
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
    let level: PuzzleDifficulty.Level
    /// The tedium the puzzle should land in.
    let range: ClosedRange<Int>
    let givens: ClosedRange<Int>
    let maxRatings: Int
    private(set) var ratings = 0
    /// The clue count range stopped the search going where the level was.
    private(set) var givensBlocked = false
    /// The closest acceptable puzzle so far: unique, rated, no guessing.
    private var best: Rated?

    init(solution: [[Int]], symmetry: Symmetry, level: PuzzleDifficulty.Level, givens: ClosedRange<Int>, maxRatings: Int) {
        self.solution = solution
        self.symmetry = symmetry
        self.level = level
        self.range = level.tediumRange
        self.givens = givens
        self.maxRatings = maxRatings
    }

    /// The closest puzzle found, or why there's none at all.
    mutating func run() -> Result<Rated, SteerMiss> {
        let level = self.level
        let range = self.range

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
        guard removed.isEmpty == false else { return .failure(.level) }

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

        // Entry: the smallest prefix whose puzzle reaches the level and the tedium window.
        // The window is a preference and the clue range a constraint: when nothing in the
        // range reaches the window (a Beginner window needs about 30 blanks; an Intermediate
        // one about 45), settle for the smallest prefix that reaches the level.
        var entry = smallestPrefix(of: removed, counts: shortest...longest) {
            $0.needsGuessing || $0.level > level || ($0.level == level && $0.tedium >= range.lowerBound)
        }
        if entry == nil, ratings < maxRatings {
            entry = smallestPrefix(of: removed, counts: shortest...longest) {
                $0.needsGuessing || $0.level >= level
            }
        }
        if Task.isCancelled { return .failure(.cancelled) }
        guard let entry else {
            // Nothing in the range reaches the level (or the budget ran out first)
            if ratings < maxRatings, longest < removed.count { givensBlocked = true }
            return climb()
        }
        guard entry.rated.result.needsGuessing == false, entry.rated.result.level == level else {
            // The order jumps straight past the level: too hard at the most clues allowed
            if entry.count == shortest, shortest > 1 { givensBlocked = true }
            return climb()
        }

        // Exit: the smallest deeper prefix that passes the level or the window. The prefixes
        // between rate at the level with more blanks as they go, so pick one at random.
        var last = longest
        if entry.count < longest {
            let exit = smallestPrefix(of: removed, counts: (entry.count + 1)...longest) {
                $0.needsGuessing || $0.level > level || $0.tedium > range.upperBound
            }
            if Task.isCancelled { return .failure(.cancelled) }
            if let exit { last = exit.count - 1 }
        }
        if last > entry.count, ratings < maxRatings {
            let candidate = prefix(removed, count: Int.random(in: entry.count...last))
            if let result = rate(candidate), result.needsGuessing == false, result.level == level {
                return .success((candidate, result))
            }
        }
        return .success(entry.rated)
    }

    /// Binary search for the smallest prefix count in `counts` whose puzzle satisfies `reached`,
    /// with its rating. Prefixes nest, so their ratings rise with the count. `nil` when none
    /// does, or the budget runs out or the task is cancelled before one is found.
    private mutating func smallestPrefix(
        of order: [[Puzzle.Index]],
        counts: ClosedRange<Int>,
        reached: (SudokuDifficultyCalculator.DifficultyResult) -> Bool
    ) -> (count: Int, rated: Rated)? {
        var low = counts.lowerBound
        var high = counts.upperBound
        var found: (count: Int, rated: Rated)?
        while low <= high, ratings < maxRatings {
            if Task.isCancelled { return nil }
            let mid = (low + high) / 2
            let candidate = prefix(order, count: mid)
            guard let result = rate(candidate) else { return found }
            if reached(result) {
                found = (mid, (candidate, result))
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        return found
    }

    /// Pushes the closest puzzle short of the level harder by swaps until it rates at the level
    /// or the budget runs out; `best` either way. Only a puzzle one level short is worth it:
    /// a swap changes a step or two, not the whole character of the puzzle.
    private mutating func climb() -> Result<Rated, SteerMiss> {
        let levels = PuzzleDifficulty.Level.allCases
        guard var current = best, current.result.level < level,
            levels.firstIndex(of: level)! - levels.firstIndex(of: current.result.level)! == 1
        else {
            return best.map { .success($0) } ?? .failure(givensBlocked ? .givens : .level)
        }
        while ratings < maxRatings, current.result.level < level {
            if Task.isCancelled { return .failure(.cancelled) }
            guard let swapped = swap(current.grid) else { continue }
            guard givens.contains(clueCount(swapped)) else {
                ratings += 1
                continue
            }
            guard let result = rate(swapped) else { continue }
            if result.needsGuessing == false, result.level <= level,
                (result.level, result.difficulty) >= (current.result.level, current.result.difficulty)
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
            let distance = distance(result)
            if best.map({ distance < self.distance($0.result) }) ?? true {
                best = (grid, result)
            }
        }
        return result
    }

    /// How far a rating is from the level: levels apart first (a level short beats one past,
    /// since a short puzzle can be climbed), then tedium outside the window.
    private func distance(_ result: SudokuDifficultyCalculator.DifficultyResult) -> Int {
        let levels = PuzzleDifficulty.Level.allCases
        let apart = abs(levels.firstIndex(of: result.level)! - levels.firstIndex(of: level)!)
        let past = result.level > level ? 5_000 : 0
        let tedium = result.tedium
        let outside = tedium < range.lowerBound ? range.lowerBound - tedium : max(0, tedium - range.upperBound)
        return apart * 10_000 + past + outside
    }

    private func set(_ orbit: [Puzzle.Index], in grid: inout [[Int]], to given: Bool) {
        for cell in orbit {
            grid[cell.row][cell.column] = given ? solution[cell.row][cell.column] : 0
        }
    }
}
