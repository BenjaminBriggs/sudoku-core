//
//  Symmetry.swift
//  SudokuCore
//

import Foundation

/// A symmetry of the clue layout: which cells are givens, not which digits they hold.
///
/// Symmetric layouts are a convention of hand-crafted puzzles, not a logic requirement.
/// The generator removes clues an orbit at a time, so the starting state keeps the layout.
public enum Symmetry: String, Codable, CaseIterable, Hashable, Sendable {
    /// No constraint on the clue layout.
    case none
    /// Rotating the grid half a turn maps the layout onto itself.
    case rotational180
    /// Rotating the grid a quarter turn maps the layout onto itself. Implies `rotational180`.
    case rotational90
    /// Reflecting across the horizontal centre line (top row ↔ bottom row).
    case mirrorHorizontal
    /// Reflecting across the vertical centre line (left column ↔ right column).
    case mirrorVertical
    /// Reflecting across the main diagonal, top-left to bottom-right.
    case diagonal
    /// Reflecting across the anti-diagonal, top-right to bottom-left.
    case antiDiagonal
    /// Both centre-line mirrors at once. Implies `mirrorHorizontal`, `mirrorVertical` and `rotational180`.
    case orthogonal
    /// Both diagonal mirrors at once. Implies `diagonal`, `antiDiagonal` and `rotational180`.
    case diagonals

    /// The cells that must be given or removed together with `index`, `index` included.
    ///
    /// Orbits have 1, 2 or 4 cells. The centre cell is its own orbit under every symmetry.
    /// For `orthogonal` and `diagonals` an orbit is every cell either mirror reaches.
    public func orbit(of index: Puzzle.Index) -> [Puzzle.Index] {
        Self.orbitTable[self]![index.row * 9 + index.column]
    }

    /// Every orbit of the grid under this symmetry, each cell in exactly one orbit.
    public var orbits: [[Puzzle.Index]] {
        Self.orbitsTable[self]!
    }

    /// Whether the clue layout of `grid` (non-zero cells) is unchanged by this symmetry.
    public func isSatisfied(by grid: [[Int]]) -> Bool {
        orbits.allSatisfy { orbit in
            let given = grid[orbit[0].row][orbit[0].column] != 0
            return orbit.allSatisfy { (grid[$0.row][$0.column] != 0) == given }
        }
    }

    /// The symmetries the clue layout of `grid` has, excluding `.none`.
    public static func symmetries(of grid: [[Int]]) -> [Symmetry] {
        allCases.filter { $0 != .none && $0.isSatisfied(by: grid) }
    }

    // MARK: - Lookup tables

    /// The single transformation this symmetry applies; composites use their two mirrors instead.
    private func image(of index: Puzzle.Index) -> Puzzle.Index {
        let r = index.row
        let c = index.column
        switch self {
        case .none, .orthogonal, .diagonals: return index
        case .rotational180: return Puzzle.Index(row: 8 - r, column: 8 - c)
        case .rotational90: return Puzzle.Index(row: c, column: 8 - r)
        case .mirrorHorizontal: return Puzzle.Index(row: 8 - r, column: c)
        case .mirrorVertical: return Puzzle.Index(row: r, column: 8 - c)
        case .diagonal: return Puzzle.Index(row: c, column: r)
        case .antiDiagonal: return Puzzle.Index(row: 8 - c, column: 8 - r)
        }
    }

    /// The transformations whose combined closure is this symmetry.
    private var generators: [Symmetry] {
        switch self {
        case .orthogonal: return [.mirrorHorizontal, .mirrorVertical]
        case .diagonals: return [.diagonal, .antiDiagonal]
        default: return [self]
        }
    }

    private func computeOrbit(of index: Puzzle.Index) -> [Puzzle.Index] {
        var orbit = [index]
        var next = 0
        while next < orbit.count {
            for generator in generators {
                let image = generator.image(of: orbit[next])
                if orbit.contains(image) == false {
                    orbit.append(image)
                }
            }
            next += 1
        }
        return orbit
    }

    private static let orbitTable: [Symmetry: [[Puzzle.Index]]] = Dictionary(
        uniqueKeysWithValues: allCases.map { symmetry in
            (symmetry, Puzzle.Index.allIndices.map { symmetry.computeOrbit(of: $0) })
        }
    )

    private static let orbitsTable: [Symmetry: [[Puzzle.Index]]] = Dictionary(
        uniqueKeysWithValues: allCases.map { symmetry in
            var seen = Set<Puzzle.Index>()
            var orbits: [[Puzzle.Index]] = []
            for index in Puzzle.Index.allIndices where seen.contains(index) == false {
                let orbit = symmetry.orbit(of: index)
                seen.formUnion(orbit)
                orbits.append(orbit)
            }
            return (symmetry, orbits)
        }
    )
}
