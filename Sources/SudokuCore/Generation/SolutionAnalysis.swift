//
//  SolutionAnalysis.swift
//  SudokuCore
//
//  Setter-facing checks on a grid of clues: how many solutions it has, whether any clue is
//  redundant, which clue would best narrow a grid with several solutions back towards one,
//  and a random solution of the clues.
//
import Foundation

/// How many solutions a grid of clues has, capped at two.
public enum SolutionCount: Sendable, Equatable {
    /// The clues clash, or no grid completes them.
    case none
    /// Exactly one solution.
    case unique(Solution)
    /// Two or more solutions. Carries the first two found, which the search finds close
    /// together, so they differ in few cells.
    case multiple(Solution, Solution)

    /// Solutions found: 0, 1 or 2 (meaning two or more).
    public var cappedCount: Int {
        switch self {
        case .none: 0
        case .unique: 1
        case .multiple: 2
        }
    }

    public var isUnique: Bool {
        if case .unique = self { return true }
        return false
    }
}

/// A clue to add to a grid: a digit at a position.
public struct SuggestedClue: Sendable, Equatable {
    public let position: Puzzle.Index
    public let value: Int

    public init(position: Puzzle.Index, value: Int) {
        self.position = position
        self.value = value
    }
}

extension Validator {
    /// Counts the grid's solutions up to two, returning the solutions it finds.
    ///
    /// Clashing clues, or clues no grid completes, give `.none`.
    public static func solutionCount(of grid: [[Int]]) -> SolutionCount {
        guard var search = BitsetSearch(grid: grid) else { return .none }
        let solutions = search.solutions(limit: 2)
        switch solutions.count {
        case 0: return .none
        case 1: return .unique(solutions[0])
        default: return .multiple(solutions[0], solutions[1])
        }
    }

    /// The grid's solutions, counted up to `limit`: 0 when the clues clash or no grid
    /// completes them.
    ///
    /// Counts beyond two say how far a grid is from unique, so a search that changes clues
    /// can follow the count down.
    public static func countSolutions(of grid: [[Int]], limit: Int) -> Int {
        guard limit > 0, var search = BitsetSearch(grid: grid) else { return 0 }
        return search.count(limit: limit)
    }

    /// Whether any grid completes the clues, or `nil` when the search gave up after
    /// `nodeLimit` branches. Proving a sparse grid has no solution can take far longer than
    /// finding one.
    public static func hasSolution(_ grid: [[Int]], nodeLimit: Int) -> Bool? {
        guard var search = BitsetSearch(grid: grid) else { return false }
        let solution = search.firstSolution(nodeLimit: nodeLimit, random: nil)
        if solution != nil { return true }
        return search.ranOut ? nil : false
    }

    /// One of the grid's solutions, found by trying digits in random order: `nil` when there's
    /// none, or the search gave up after `nodeLimit` branches.
    public static func randomSolution(
        of grid: [[Int]],
        using generator: inout some RandomNumberGenerator,
        nodeLimit: Int = 100_000
    ) -> Solution? {
        guard var search = BitsetSearch(grid: grid) else { return nil }
        return search.firstSolution(nodeLimit: nodeLimit, random: SearchRandom(seed: generator.next()))
    }

    /// Positions where two grids hold different digits, in row-major order.
    public static func differingCells(_ first: Solution, _ second: Solution) -> [Puzzle.Index] {
        Puzzle.Index.allIndices.filter {
            first[$0.row][$0.column] != second[$0.row][$0.column]
        }
    }

    /// Clues that can each be removed on their own without losing a unique solution.
    ///
    /// Empty when the grid is minimal, and also when it doesn't have exactly one solution
    /// to begin with, since minimality only means something for a unique grid.
    public static func redundantClues(in grid: [[Int]]) -> [Puzzle.Index] {
        guard solutionCount(of: grid).isUnique else { return [] }
        return Puzzle.Index.allIndices.filter { position in
            guard grid[position.row][position.column] != 0 else { return false }
            var reduced = grid
            reduced[position.row][position.column] = 0
            return solutionCount(of: reduced).isUnique
        }
    }

    /// Whether the grid has a unique solution and no clue can be removed without losing it.
    public static func isMinimal(_ grid: [[Int]]) -> Bool {
        solutionCount(of: grid).isUnique && redundantClues(in: grid).isEmpty
    }

    /// Picks one clue to add to a grid with several solutions that narrows it the most.
    ///
    /// Tries each cell where the two sample solutions differ, with either solution's digit.
    /// A clue that leaves exactly one solution wins at once; otherwise the clue whose next
    /// pair of sample solutions differs in the fewest cells. `nil` when the grid doesn't have
    /// several solutions.
    public static func suggestedClue(for grid: [[Int]]) -> SuggestedClue? {
        guard case .multiple(let first, let second) = solutionCount(of: grid) else { return nil }
        return suggestedClue(for: grid, between: first, and: second)
    }

    /// As `suggestedClue(for:)`, given the two sample solutions already found for the grid.
    public static func suggestedClue(
        for grid: [[Int]],
        between first: Solution,
        and second: Solution
    ) -> SuggestedClue? {
        var best: (clue: SuggestedClue, remaining: Int)?
        for position in differingCells(first, second) {
            for value in [first[position.row][position.column], second[position.row][position.column]] {
                var narrowed = grid
                narrowed[position.row][position.column] = value
                let clue = SuggestedClue(position: position, value: value)
                // Both values come from real solutions, so there's always at least one.
                let count = solutionCount(of: narrowed)
                if case .unique = count { return clue }
                if case .multiple(let a, let b) = count {
                    let remaining = differingCells(a, b).count
                    if remaining < best?.remaining ?? .max {
                        best = (clue, remaining)
                    }
                }
            }
        }
        return best?.clue
    }
}

/// A small, fast generator for searches that take their randomness from a caller's generator
/// once, as a seed, so the same seed always gives the same search.
struct SearchRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// SplitMix64.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A backtracking search over row, column and box bitsets that stops after `limit` solutions,
/// always branching on the empty cell with the fewest candidates.
struct BitsetSearch {
    private var grid: [[Int]]
    private var rows = [Int](repeating: 0, count: 9)
    private var columns = [Int](repeating: 0, count: 9)
    private var boxes = [Int](repeating: 0, count: 9)
    private var found: [Solution] = []
    private var count = 0
    private var keepsSolutions = true
    /// Per square and digit, the solutions that hold it, indexed `square * 9 + digit - 1`.
    /// Empty unless tallying.
    private var tallied: [Int] = []
    private(set) var nodes = 0
    private var nodeLimit = Int.max
    /// Tries a branch's digits in random order when set.
    private var random: SearchRandom?
    /// The search stopped at `nodeLimit` before it finished, or a tally's task was cancelled.
    private(set) var ranOut = false

    /// `nil` when the grid isn't 9×9, holds a digit outside 0…9, or its clues clash.
    init?(grid: [[Int]]) {
        guard grid.count == 9, grid.allSatisfy({ $0.count == 9 }) else { return nil }
        self.grid = grid
        for row in 0..<9 {
            for column in 0..<9 {
                let value = grid[row][column]
                guard value != 0 else { continue }
                guard (1...9).contains(value) else { return nil }
                let bit = 1 << (value - 1)
                let box = (row / 3) * 3 + column / 3
                guard rows[row] & bit == 0, columns[column] & bit == 0, boxes[box] & bit == 0 else {
                    return nil
                }
                rows[row] |= bit
                columns[column] |= bit
                boxes[box] |= bit
            }
        }
    }

    /// Clears what an earlier search left, so a search can be used again in any mode.
    private mutating func reset(nodeLimit: Int = .max, random: SearchRandom? = nil) {
        found = []
        tallied = []
        count = 0
        nodes = 0
        ranOut = false
        self.nodeLimit = nodeLimit
        self.random = random
    }

    mutating func solutions(limit: Int) -> [Solution] {
        reset()
        keepsSolutions = true
        search(limit: limit)
        return found
    }

    /// Solutions up to `limit`, counted without keeping them.
    mutating func count(limit: Int) -> Int {
        reset()
        keepsSolutions = false
        search(limit: limit)
        return count
    }

    /// How many of the first `limit` solutions hold each digit in each square, indexed
    /// `square * 9 + digit - 1`, and how many solutions that was. Stops after `nodeLimit`
    /// branches.
    mutating func tally(limit: Int, nodeLimit: Int) -> (counts: [Int], solutions: Int) {
        reset(nodeLimit: nodeLimit)
        tallied = [Int](repeating: 0, count: 81 * 9)
        keepsSolutions = false
        search(limit: limit)
        return (tallied, count)
    }

    /// The first solution found within `nodeLimit` branches, trying digits in `random` order.
    mutating func firstSolution(nodeLimit: Int, random: SearchRandom?) -> Solution? {
        reset(nodeLimit: nodeLimit, random: random)
        keepsSolutions = true
        search(limit: 1)
        return found.first
    }

    private mutating func search(limit: Int) {
        nodes += 1
        // A tally is the one search long enough to be worth stopping when its task is cancelled.
        if nodes > nodeLimit || (tallied.isEmpty == false && nodes & 0xFFF == 0 && Task.isCancelled) {
            ranOut = true
            return
        }
        // Candidates for every cell, 0 for a filled one. An empty cell with none is a dead end.
        var candidates = [Int](repeating: 0, count: 81)
        var bestCell = -1
        var bestCount = 10
        for row in 0..<9 {
            for column in 0..<9 where grid[row][column] == 0 {
                let used = rows[row] | columns[column] | boxes[(row / 3) * 3 + column / 3]
                let cellCandidates = ~used & 0b1_1111_1111
                let count = cellCandidates.nonzeroBitCount
                if count == 0 { return }
                candidates[row * 9 + column] = cellCandidates
                if count < bestCount {
                    bestCell = row * 9 + column
                    bestCount = count
                }
            }
        }

        guard bestCell >= 0 else {
            count += 1
            if keepsSolutions { found.append(grid) }
            return
        }

        var branchCell = bestCell
        var branchDigits = candidates[bestCell]

        // A digit with one place left in a row, column or box is forced there, which prunes
        // far more than branching on the fewest candidates alone. A digit with no place left
        // is a dead end.
        if bestCount > 1 {
            hiddenSingles: for unit in Self.units {
                var once = 0
                var twice = 0
                var placed = 0
                for cell in unit {
                    let cellCandidates = candidates[cell]
                    if cellCandidates == 0 {
                        placed |= 1 << (grid[cell / 9][cell % 9] - 1)
                    }
                    twice |= once & cellCandidates
                    once |= cellCandidates
                }
                if (once | placed) != 0b1_1111_1111 { return }
                let single = once & ~twice
                guard single != 0 else { continue }
                let bit = single & -single
                for cell in unit where candidates[cell] & bit != 0 {
                    branchCell = cell
                    branchDigits = bit
                    break hiddenSingles
                }
            }
        }

        let row = branchCell / 9
        let column = branchCell % 9
        let box = (row / 3) * 3 + column / 3
        // Lowest digit first, unless the search is random; only then is an order worth building.
        var order = branchDigits
        var shuffled: [Int] = []
        if random != nil, branchDigits.nonzeroBitCount > 1 {
            while order != 0 {
                shuffled.append(order & -order)
                order &= order - 1
            }
            shuffled.shuffle(using: &random!)
        }
        var next = 0
        while true {
            let bit: Int
            if shuffled.isEmpty {
                guard order != 0 else { return }
                bit = order & -order
                order &= order - 1
            } else {
                guard next < shuffled.count else { return }
                bit = shuffled[next]
                next += 1
            }
            grid[row][column] = bit.trailingZeroBitCount + 1
            rows[row] |= bit
            columns[column] |= bit
            boxes[box] |= bit
            let countBefore = count
            search(limit: limit)
            // Every solution found under this branch holds its digit here.
            if tallied.isEmpty == false {
                tallied[branchCell * 9 + bit.trailingZeroBitCount] += count - countBefore
            }
            rows[row] &= ~bit
            columns[column] &= ~bit
            boxes[box] &= ~bit
            grid[row][column] = 0
            if count >= limit || ranOut { return }
        }
    }

    /// The 27 rows, columns and boxes, as flat cell indices.
    private static let units: [[Int]] = {
        let rows = (0..<9).map { row in (0..<9).map { row * 9 + $0 } }
        let columns = (0..<9).map { column in (0..<9).map { $0 * 9 + column } }
        let boxes = (0..<9).map { box in
            (0..<9).map { ((box / 3) * 3 + $0 / 3) * 9 + (box % 3) * 3 + $0 % 3 }
        }
        return rows + columns + boxes
    }()
}
