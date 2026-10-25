//
//  SolutionAnalysis.swift
//  SudokuCore
//
//  Setter-facing checks on a grid of clues: how many solutions it has (capped at two),
//  whether any clue is redundant, and which clue would best narrow a grid with several
//  solutions back towards one.
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
                switch solutionCount(of: narrowed) {
                case .unique:
                    return clue
                case .multiple(let a, let b):
                    let remaining = differingCells(a, b).count
                    if remaining < best?.remaining ?? .max {
                        best = (clue, remaining)
                    }
                case .none:
                    // Both values come from real solutions, so this can't happen.
                    continue
                }
            }
        }
        return best?.clue
    }
}

/// A backtracking search over row, column and box bitsets that stops after `limit` solutions,
/// always branching on the empty cell with the fewest candidates.
private struct BitsetSearch {
    private var grid: [[Int]]
    private var rows = [Int](repeating: 0, count: 9)
    private var columns = [Int](repeating: 0, count: 9)
    private var boxes = [Int](repeating: 0, count: 9)
    private var found: [Solution] = []

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

    mutating func solutions(limit: Int) -> [Solution] {
        found = []
        search(limit: limit)
        return found
    }

    private mutating func search(limit: Int) {
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
            found.append(grid)
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
        var remaining = branchDigits
        while remaining != 0 {
            let bit = remaining & -remaining
            remaining &= remaining - 1
            grid[row][column] = bit.trailingZeroBitCount + 1
            rows[row] |= bit
            columns[column] |= bit
            boxes[box] |= bit
            search(limit: limit)
            rows[row] &= ~bit
            columns[column] &= ~bit
            boxes[box] &= ~bit
            grid[row][column] = 0
            if found.count >= limit { return }
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
