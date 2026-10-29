//
//  PlanFiller+Suggestions.swift
//  SudokuCore
//
//  When a plan can't be filled, which squares to add: for a closed plan, squares in the lines
//  that can swap; otherwise squares where the nearest miss still has a choice.
//
import Foundation

extension PlanFiller {
    /// No sudoku with fewer clues has one solution.
    public static let minimumSquares = 17

    /// The fill the search came closest with: its digits, how many solutions they leave (capped
    /// at 64), and the squares where two of those solutions differ.
    public struct NearMiss: Sendable, Equatable {
        public let grid: [[Int]]
        public let solutionCount: Int
        public let differing: [Puzzle.Index]
    }

    /// The grid with the fewest solutions the budget's walks reach. A fill, if one turns up,
    /// is a near miss with one solution and nothing differing. `nil` when no walk can start.
    public static func nearestFill(_ request: Request, seed: UInt64, budget: Budget) async -> NearMiss? {
        let deadline = budget.timeout.map { ContinuousClock.now + $0 }
        let best = await withTaskGroup(of: Walk.self) { group in
            for walk in 0..<budget.walks {
                group.addTask {
                    var generator = SearchRandom(seed: seed &+ UInt64(walk) &* 0x9E37_79B9_7F4A_7C15)
                    return Self.walk(request, using: &generator, maxMoves: budget.movesPerWalk, deadline: deadline, near: nil)
                }
            }
            var best = Walk()
            for await result in group {
                if let fill = result.fill {
                    group.cancelAll()
                    return Walk(fill: fill, nearest: fill, nearestCount: 1)
                }
                if result.nearestCount < best.nearestCount { best = result }
            }
            return best
        }
        guard let grid = best.fill ?? best.nearest else { return nil }
        guard best.fill == nil else { return NearMiss(grid: grid, solutionCount: 1, differing: []) }
        var differing: [Puzzle.Index] = []
        if case .multiple(let first, let second) = Validator.solutionCount(of: grid) {
            differing = Validator.differingCells(first, second)
        }
        return NearMiss(grid: grid, solutionCount: best.nearestCount, differing: differing)
    }

    /// Orbits of `symmetry` (single squares without one) to add to the plan, best first, at
    /// most `limit`. For a closed plan, the orbits covering the most of the lines that can
    /// swap; otherwise the orbits covering the most squares where the nearest miss still has a
    /// choice. Empty when the plan already fills, or nothing helps.
    public static func squaresToAdd(
        _ request: Request,
        symmetry: Symmetry?,
        seed: UInt64,
        budget: Budget,
        limit: Int = 3
    ) async -> [[Puzzle.Index]] {
        let orbits = (symmetry ?? .none).orbits.filter { orbit in
            orbit.allSatisfy { request.plan.contains($0) == false }
        }
        let swappable = swappableLines(in: request.plan)
        let targets: Set<Puzzle.Index>
        if swappable.isEmpty == false {
            targets = Set(swappable.flatMap { lines in
                lines.lines.flatMap { line in
                    (0..<9).map { lines.kind == .rows ? Puzzle.Index(row: line, column: $0) : Puzzle.Index(row: $0, column: line) }
                }
            })
        } else {
            guard let near = await nearestFill(request, seed: seed, budget: budget), near.solutionCount > 1 else { return [] }
            targets = Set(near.differing)
        }
        return Array(
            orbits
                .map { orbit in (orbit: orbit, covered: orbit.filter(targets.contains).count) }
                .filter { $0.covered > 0 }
                .sorted { ($0.covered, -$0.orbit.count) > ($1.covered, -$1.orbit.count) }
                .prefix(limit)
                .map(\.orbit)
        )
    }
}
