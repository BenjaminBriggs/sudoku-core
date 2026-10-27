//
//  ReferenceTechniques.swift
//  SudokuCore
//
//  Definition-level reference finders used to verify `HintFinder`.
//
//  Each finder is written for obviousness, not speed: it enumerates every instance of a
//  technique straight from the textbook definition and returns everything those instances
//  license. `TechniqueVerificationTests` compares the production finders against them.
//
import Foundation
@testable import SudokuCore

enum Reference {
    /// A (cell, digit) pair.
    struct Candidate: Hashable, CustomStringConvertible {
        let row: Int
        let column: Int
        let digit: Int

        init(_ cell: Puzzle.Index, _ digit: Int) {
            self.row = cell.row
            self.column = cell.column
            self.digit = digit
        }

        var description: String { "r\(row + 1)c\(column + 1)#\(digit)" }
    }

    /// Every placement and elimination any instance of a technique licenses.
    struct Licensed {
        var placements = Set<Candidate>()
        var eliminations = Set<Candidate>()

        var isEmpty: Bool { placements.isEmpty && eliminations.isEmpty }
    }

    // MARK: - Geometry

    static let rows: [[Puzzle.Index]] = (0..<9).map { r in (0..<9).map { Puzzle.Index(row: r, column: $0) } }
    static let columns: [[Puzzle.Index]] = (0..<9).map { c in (0..<9).map { Puzzle.Index(row: $0, column: c) } }
    static let boxes: [[Puzzle.Index]] = (0..<9).map { b in
        (0..<9).map { Puzzle.Index(row: (b / 3) * 3 + $0 / 3, column: (b % 3) * 3 + $0 % 3) }
    }
    static let units = rows + columns + boxes
    static let allCells = rows.flatMap { $0 }

    static func box(of cell: Puzzle.Index) -> Int { (cell.row / 3) * 3 + cell.column / 3 }

    static func sees(_ a: Puzzle.Index, _ b: Puzzle.Index) -> Bool {
        a != b && (a.row == b.row || a.column == b.column || box(of: a) == box(of: b))
    }

    /// Cells (other than the arguments) that see every one of `cells`.
    static func commonPeers(_ cells: [Puzzle.Index]) -> [Puzzle.Index] {
        allCells.filter { candidate in
            cells.contains(candidate) == false && cells.allSatisfy { sees(candidate, $0) }
        }
    }

    // MARK: - Board view

    struct Board {
        let grid: [[Int]]
        let candidates: [[Set<Int>]]

        init(_ state: BoardState) {
            grid = state.grid
            candidates = (0..<9).map { r in
                (0..<9).map { c in state.grid[r][c] == 0 ? state.pencilMarks[r][c] : [] }
            }
        }

        func isEmpty(_ cell: Puzzle.Index) -> Bool { grid[cell.row][cell.column] == 0 }
        func candidates(_ cell: Puzzle.Index) -> Set<Int> { candidates[cell.row][cell.column] }
        func has(_ cell: Puzzle.Index, _ digit: Int) -> Bool { candidates(cell).contains(digit) }
        func cells(in unit: [Puzzle.Index], with digit: Int) -> [Puzzle.Index] { unit.filter { has($0, digit) } }
        func isPlaced(_ digit: Int, in unit: [Puzzle.Index]) -> Bool { unit.contains { grid[$0.row][$0.column] == digit } }
        func emptyCells(in unit: [Puzzle.Index]) -> [Puzzle.Index] { unit.filter(isEmpty) }

        /// Pairs of cells that are the only two homes for `digit` in some unit.
        func conjugatePairs(_ digit: Int, in units: [[Puzzle.Index]]) -> [(Puzzle.Index, Puzzle.Index)] {
            units.compactMap { unit in
                let cells = cells(in: unit, with: digit)
                return cells.count == 2 ? (cells[0], cells[1]) : nil
            }
        }
    }

    // MARK: - Dispatch

    static func licensed(_ technique: HintTechnique, in state: BoardState) -> Licensed {
        let board = Board(state)
        switch technique {
        case .nakedSingle: return nakedSingles(board)
        case .hiddenSingle: return hiddenSingles(board)
        case .lockedCandidatesPointing: return pointing(board)
        case .lockedCandidatesClaiming: return claiming(board)
        case .nakedPair: return nakedSubsets(board, size: 2)
        case .nakedTriple: return nakedSubsets(board, size: 3)
        case .nakedQuad: return nakedSubsets(board, size: 4)
        case .hiddenPair: return hiddenSubsets(board, size: 2)
        case .hiddenTriple: return hiddenSubsets(board, size: 3)
        case .hiddenQuad: return hiddenSubsets(board, size: 4)
        case .xWing: return fish(board, size: 2, finned: false)
        case .swordfish: return fish(board, size: 3, finned: false)
        case .jellyfish: return fish(board, size: 4, finned: false)
        case .finnedXWing: return fish(board, size: 2, finned: true)
        case .finnedSwordfish: return fish(board, size: 3, finned: true)
        case .finnedJellyfish: return fish(board, size: 4, finned: true)
        case .skyscraper: return skyscraper(board)
        case .twoStringKite: return twoStringKite(board)
        case .emptyRectangle: return emptyRectangle(board)
        case .xyWing, .yWing: return xyWing(board)
        case .xyzWing: return xyzWing(board)
        case .wWing: return wWing(board)
        case .validation, .unknown: return Licensed()
        }
    }

    // MARK: - Singles

    /// A cell with one candidate holds it.
    static func nakedSingles(_ b: Board) -> Licensed {
        var out = Licensed()
        for cell in allCells where b.isEmpty(cell) && b.candidates(cell).count == 1 {
            out.placements.insert(Candidate(cell, b.candidates(cell).first!))
        }
        return out
    }

    /// A digit with one home in a unit goes there. A cell with no other candidate is a
    /// naked single instead, so it doesn't count.
    static func hiddenSingles(_ b: Board) -> Licensed {
        var out = Licensed()
        for unit in units {
            for digit in 1...9 where b.isPlaced(digit, in: unit) == false {
                let cells = b.cells(in: unit, with: digit)
                if cells.count == 1, b.candidates(cells[0]).count > 1 { out.placements.insert(Candidate(cells[0], digit)) }
            }
        }
        return out
    }

    // MARK: - Locked candidates

    /// A box's copies of a digit all lie on one line, so the rest of that line loses it.
    static func pointing(_ b: Board) -> Licensed {
        var out = Licensed()
        for box in boxes {
            for digit in 1...9 {
                let cells = b.cells(in: box, with: digit)
                guard cells.count >= 2 else { continue }
                for line in rows + columns where cells.allSatisfy(line.contains) {
                    for cell in line where box.contains(cell) == false && b.has(cell, digit) {
                        out.eliminations.insert(Candidate(cell, digit))
                    }
                }
            }
        }
        return out
    }

    /// A line's copies of a digit all lie in one box, so the rest of that box loses it.
    static func claiming(_ b: Board) -> Licensed {
        var out = Licensed()
        for line in rows + columns {
            for digit in 1...9 {
                let cells = b.cells(in: line, with: digit)
                guard cells.count >= 2 else { continue }
                for box in boxes where cells.allSatisfy(box.contains) {
                    for cell in box where line.contains(cell) == false && b.has(cell, digit) {
                        out.eliminations.insert(Candidate(cell, digit))
                    }
                }
            }
        }
        return out
    }

    // MARK: - Subsets

    /// `size` cells in a unit holding only `size` digits between them claim those digits.
    static func nakedSubsets(_ b: Board, size: Int) -> Licensed {
        var out = Licensed()
        for unit in units {
            let empty = b.emptyCells(in: unit)
            for cells in empty.choose(size) {
                let digits = cells.reduce(into: Set<Int>()) { $0.formUnion(b.candidates($1)) }
                guard digits.count == size else { continue }
                for cell in empty where cells.contains(cell) == false {
                    for digit in b.candidates(cell).intersection(digits) {
                        out.eliminations.insert(Candidate(cell, digit))
                    }
                }
            }
        }
        return out
    }

    /// `size` digits confined to the same `size` cells of a unit own those cells.
    static func hiddenSubsets(_ b: Board, size: Int) -> Licensed {
        var out = Licensed()
        for unit in units {
            let digits = (1...9).filter { b.isPlaced($0, in: unit) == false && b.cells(in: unit, with: $0).isEmpty == false }
            for subset in digits.choose(size) {
                let cells = subset.reduce(into: Set<Puzzle.Index>()) { $0.formUnion(b.cells(in: unit, with: $1)) }
                guard cells.count == size else { continue }
                for cell in cells {
                    for digit in b.candidates(cell).subtracting(subset) {
                        out.eliminations.insert(Candidate(cell, digit))
                    }
                }
            }
        }
        return out
    }

    // MARK: - Fish

    /// `size` base lines whose copies of a digit fit in `size` cover lines. A finned fish has
    /// extra base cells (fins) outside the covers, all in one box; it only eliminates from
    /// cover cells that see every fin. Sashimi fish are finned fish whose base line has lost
    /// a cover cell, so they are included.
    static func fish(_ b: Board, size: Int, finned: Bool) -> Licensed {
        var out = Licensed()
        for digit in 1...9 {
            for rowBased in [true, false] {
                let baseLines = rowBased ? rows : columns
                let cross: (Puzzle.Index) -> Int = rowBased ? { $0.column } : { $0.row }
                let base: (Puzzle.Index) -> Int = rowBased ? { $0.row } : { $0.column }
                let candidateBases = (0..<9).filter { b.cells(in: baseLines[$0], with: digit).count >= 2 }
                for bases in candidateBases.choose(size) {
                    let baseCells = bases.flatMap { b.cells(in: baseLines[$0], with: digit) }
                    let crossLines = Set(baseCells.map(cross)).sorted()
                    for covers in crossLines.choose(size) {
                        let fins = baseCells.filter { covers.contains(cross($0)) == false }
                        guard fins.isEmpty != finned else { continue }
                        if finned, Set(fins.map(box(of:))).count != 1 { continue }
                        for cell in allCells where covers.contains(cross(cell)) && bases.contains(base(cell)) == false {
                            guard b.has(cell, digit), fins.allSatisfy({ sees(cell, $0) }) else { continue }
                            out.eliminations.insert(Candidate(cell, digit))
                        }
                    }
                }
            }
        }
        return out
    }

    // MARK: - Single-digit patterns

    /// Two parallel conjugate lines with one pair of ends on a shared cross line: one of the
    /// two other ends is true, so cells seeing both lose the digit.
    static func skyscraper(_ b: Board) -> Licensed {
        var out = Licensed()
        for digit in 1...9 {
            for rowBased in [true, false] {
                let cross: (Puzzle.Index) -> Int = rowBased ? { $0.column } : { $0.row }
                let pairs = b.conjugatePairs(digit, in: rowBased ? rows : columns)
                for (first, second) in pairs.choose(2).map({ ($0[0], $0[1]) }) {
                    for (a, tip1) in [(first.0, first.1), (first.1, first.0)] {
                        for (c, tip2) in [(second.0, second.1), (second.1, second.0)] {
                            guard cross(a) == cross(c), cross(tip1) != cross(tip2) else { continue }
                            for cell in commonPeers([tip1, tip2]) where [a, c].contains(cell) == false && b.has(cell, digit) {
                                out.eliminations.insert(Candidate(cell, digit))
                            }
                        }
                    }
                }
            }
        }
        return out
    }

    /// A row conjugate pair and a column conjugate pair with one end of each in the same box:
    /// one of the two far ends is true, so cells seeing both lose the digit.
    static func twoStringKite(_ b: Board) -> Licensed {
        var out = Licensed()
        for digit in 1...9 {
            for rowPair in b.conjugatePairs(digit, in: rows) {
                for columnPair in b.conjugatePairs(digit, in: columns) {
                    for (a, tip1) in [(rowPair.0, rowPair.1), (rowPair.1, rowPair.0)] {
                        for (c, tip2) in [(columnPair.0, columnPair.1), (columnPair.1, columnPair.0)] {
                            guard Set([a, tip1, c, tip2]).count == 4, box(of: a) == box(of: c) else { continue }
                            for cell in commonPeers([tip1, tip2]) where [a, c].contains(cell) == false && b.has(cell, digit) {
                                out.eliminations.insert(Candidate(cell, digit))
                            }
                        }
                    }
                }
            }
        }
        return out
    }

    /// A box whose copies of a digit lie on one row and one column (but not just one of them),
    /// joined to a conjugate line outside the box. The cell where the far end's line meets the
    /// box's other line loses the digit.
    static func emptyRectangle(_ b: Board) -> Licensed {
        var out = Licensed()
        for digit in 1...9 {
            for (boxIndex, box) in boxes.enumerated() {
                let cells = b.cells(in: box, with: digit)
                guard cells.count >= 2 else { continue }
                let boxRows = Set(box.map(\.row)), boxColumns = Set(box.map(\.column))
                for r in boxRows {
                    for c in boxColumns {
                        guard cells.allSatisfy({ $0.row == r || $0.column == c }),
                              cells.allSatisfy({ $0.row == r }) == false,
                              cells.allSatisfy({ $0.column == c }) == false else { continue }
                        for (pair, isColumn) in b.conjugatePairs(digit, in: columns).map({ ($0, true) })
                            + b.conjugatePairs(digit, in: rows).map({ ($0, false) }) {
                            for (near, far) in [(pair.0, pair.1), (pair.1, pair.0)] {
                                guard Self.box(of: near) != boxIndex, Self.box(of: far) != boxIndex else { continue }
                                let target: Puzzle.Index
                                if isColumn, near.row == r {
                                    target = Puzzle.Index(row: far.row, column: c)
                                } else if isColumn == false, near.column == c {
                                    target = Puzzle.Index(row: r, column: far.column)
                                } else {
                                    continue
                                }
                                guard Self.box(of: target) != boxIndex, b.has(target, digit) else { continue }
                                out.eliminations.insert(Candidate(target, digit))
                            }
                        }
                    }
                }
            }
        }
        return out
    }

    // MARK: - Wings

    /// Pivot {x,y} seeing wings {x,z} and {y,z}: one wing is z, so cells seeing both lose z.
    static func xyWing(_ b: Board) -> Licensed {
        var out = Licensed()
        let bivalue = allCells.filter { b.isEmpty($0) && b.candidates($0).count == 2 }
        for pivot in bivalue {
            let pair = b.candidates(pivot).sorted()
            for (x, y) in [(pair[0], pair[1]), (pair[1], pair[0])] {
                for wing1 in bivalue where sees(wing1, pivot) && b.has(wing1, x) && b.has(wing1, y) == false {
                    let z = b.candidates(wing1).subtracting([x]).first!
                    for wing2 in bivalue where sees(wing2, pivot) && wing2 != wing1 && b.candidates(wing2) == [y, z] {
                        for cell in commonPeers([wing1, wing2]) where cell != pivot && b.has(cell, z) {
                            out.eliminations.insert(Candidate(cell, z))
                        }
                    }
                }
            }
        }
        return out
    }

    /// Pivot {x,y,z} seeing wings {x,z} and {y,z}: one of the three is z, so cells seeing all
    /// three lose z.
    static func xyzWing(_ b: Board) -> Licensed {
        var out = Licensed()
        let bivalue = allCells.filter { b.isEmpty($0) && b.candidates($0).count == 2 }
        for pivot in allCells where b.isEmpty(pivot) && b.candidates(pivot).count == 3 {
            let wings = bivalue.filter { sees($0, pivot) && b.candidates($0).isSubset(of: b.candidates(pivot)) }
            for pair in wings.choose(2) {
                let shared = b.candidates(pair[0]).intersection(b.candidates(pair[1]))
                guard b.candidates(pair[0]) != b.candidates(pair[1]), shared.count == 1, let z = shared.first else { continue }
                for cell in commonPeers([pivot, pair[0], pair[1]]) where b.has(cell, z) {
                    out.eliminations.insert(Candidate(cell, z))
                }
            }
        }
        return out
    }

    /// Two unconnected {x,y} cells, each seeing one end of a conjugate pair on x: one of them
    /// is y, so cells seeing both lose y.
    static func wWing(_ b: Board) -> Licensed {
        var out = Licensed()
        let bivalue = allCells.filter { b.isEmpty($0) && b.candidates($0).count == 2 }
        for pair in bivalue.choose(2) {
            let (a, c) = (pair[0], pair[1])
            guard b.candidates(a) == b.candidates(c), sees(a, c) == false else { continue }
            for x in b.candidates(a) {
                let y = b.candidates(a).subtracting([x]).first!
                for link in b.conjugatePairs(x, in: units) {
                    guard [link.0, link.1].contains(a) == false, [link.0, link.1].contains(c) == false else { continue }
                    let joined = (sees(link.0, a) && sees(link.1, c)) || (sees(link.1, a) && sees(link.0, c))
                    guard joined else { continue }
                    for cell in commonPeers([a, c]) where b.has(cell, y) {
                        out.eliminations.insert(Candidate(cell, y))
                    }
                }
            }
        }
        return out
    }
}

extension Array {
    /// Every `count`-element combination, in order. Kept local so the reference shares no
    /// helpers with the code it checks.
    func choose(_ count: Int) -> [[Element]] {
        guard count > 0 else { return [[]] }
        guard count <= self.count else { return [] }
        var result: [[Element]] = []
        func build(_ start: Int, _ partial: [Element]) {
            if partial.count == count { result.append(partial); return }
            guard start < self.count, self.count - start >= count - partial.count else { return }
            for i in start..<self.count { build(i + 1, partial + [self[i]]) }
        }
        build(0, [])
        return result
    }
}
