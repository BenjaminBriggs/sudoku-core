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
//  Each finder cites the definition it follows. Where core deliberately narrows or departs
//  from a source, the reference records the same choice:
//  - Hidden single skips a cell whose only candidate is the digit; that's a naked single.
//  - Pointing and claiming need two or more cells; a lone candidate is a hidden single.
//  - W-Wing cells must not see each other; if they do, it's a naked pair.
//  - Finned fish keep every fin in one box, sashimi included.
//  - n-Y-Wings require every digit but z to be restricted, which Sudoku Coach's shape
//    alone doesn't guarantee (see the near-miss fixture).
//  - Unique Rectangles need four empty corners over exactly two boxes, and like BUG+1 only
//    run when the board is known to have one solution.
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

    /// What every technique licenses on `state`, sharing the one n-Y-Wing enumeration.
    static func licensedAll(_ techniques: [HintTechnique], in state: BoardState) -> [HintTechnique: Licensed] {
        let wings = nYWings(Board(state))
        let sizes: [HintTechnique: Int] = [.fourYWing: 4, .fiveYWing: 5, .sixYWing: 6, .sevenYWing: 7]
        var out: [HintTechnique: Licensed] = [:]
        for technique in techniques {
            if let size = sizes[technique] {
                out[technique] = wings[size] ?? Licensed()
            } else {
                out[technique] = licensed(technique, in: state)
            }
        }
        return out
    }

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
        case .xyWing: return xyWing(board)
        case .xyzWing: return xyzWing(board)
        case .wWing: return wWing(board)
        case .crane: return crane(board)
        case .fourYWing: return nYWings(board)[4] ?? Licensed()
        case .fiveYWing: return nYWings(board)[5] ?? Licensed()
        case .sixYWing: return nYWings(board)[6] ?? Licensed()
        case .sevenYWing: return nYWings(board)[7] ?? Licensed()
        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType3,
             .uniqueRectangleType4, .uniqueRectangleType5, .bug:
            guard state.assumesUniqueSolution else { return Licensed() }
            switch technique {
            case .uniqueRectangleType1: return uniqueRectangle(board, type: 1)
            case .uniqueRectangleType2: return uniqueRectangle(board, type: 2)
            case .uniqueRectangleType3: return uniqueRectangle(board, type: 3)
            case .uniqueRectangleType4: return uniqueRectangle(board, type: 4)
            case .uniqueRectangleType5: return uniqueRectangle(board, type: 5)
            default: return bug(board)
            }
        case .validation, .unknown: return Licensed()
        }
    }

    // MARK: - Singles

    /// A cell with one candidate holds it.
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_singles.php.
    static func nakedSingles(_ b: Board) -> Licensed {
        var out = Licensed()
        for cell in allCells where b.isEmpty(cell) && b.candidates(cell).count == 1 {
            out.placements.insert(Candidate(cell, b.candidates(cell).first!))
        }
        return out
    }

    /// A digit with one home in a unit goes there. A cell with no other candidate is a
    /// naked single instead, so it doesn't count.
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_singles.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_intersections.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_intersections.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_naked.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_hidden.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_fishb.php and http://hodoku.sourceforge.net/en/tech_fishfs.php.
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
                    // Without fins every base cell is in a cover line. Fins sit in one box,
                    // which spans three cross lines, so a finned fish has at most size + 3.
                    guard crossLines.count <= size + (finned ? 3 : 0) else { continue }
                    for covers in crossLines.choose(size) {
                        let fins = baseCells.filter { covers.contains(cross($0)) == false }
                        guard fins.isEmpty != finned else { continue }
                        if finned, Set(fins.map(box(of:))).count != 1 { continue }
                        for cover in covers {
                            for cell in (rowBased ? columns : rows)[cover] where bases.contains(base(cell)) == false {
                                guard b.has(cell, digit), fins.allSatisfy({ sees(cell, $0) }) else { continue }
                                out.eliminations.insert(Candidate(cell, digit))
                            }
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_sdp.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_sdp.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_sdp.php.
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

        /// A conjugate pair in a box and one in a line, one end of each seeing the other: one of
    /// the two far ends is true, so cells seeing both lose the digit.
    ///
    /// Source: https://sudoku.coach/en/learn/crane (a Turbot Fish in http://hodoku.sourceforge.net/en/tech_sdp.php).
    static func crane(_ b: Board) -> Licensed {
        var out = Licensed()
        for digit in 1...9 {
            for boxPair in b.conjugatePairs(digit, in: boxes) {
                for linePair in b.conjugatePairs(digit, in: rows + columns) {
                    for (joint1, tip1) in [(boxPair.0, boxPair.1), (boxPair.1, boxPair.0)] {
                        for (joint2, tip2) in [(linePair.0, linePair.1), (linePair.1, linePair.0)] {
                            let four = [joint1, tip1, joint2, tip2]
                            guard Set(four).count == 4, sees(joint1, joint2) else { continue }
                            for cell in commonPeers([tip1, tip2]) where four.contains(cell) == false && b.has(cell, digit) {
                                out.eliminations.insert(Candidate(cell, digit))
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_wings.php.
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
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_wings.php.
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

    /// n cells holding n digits (n = 4...7): a pivot group inside one unit, wings that each see
    /// every pivot, and exactly one digit z whose copies don't all see each other. Every other
    /// digit fills at most one cell, so one of the cells is z; cells seeing every z lose it.
    ///
    /// All four sizes come from one enumeration, keyed by size. Cells are 0...80 and candidates
    /// bitmasks here, purely for speed: the search is the definition, case by case.
    ///
    /// Source: https://sudoku.coach/en/learn/wxyz-wing, made sound by requiring every digit but z to be restricted.
    static func nYWings(_ b: Board) -> [Int: Licensed] {
        var out: [Int: Licensed] = [:]
        let masks = allCells.map { cell in
            b.isEmpty(cell) && b.candidates(cell).count >= 2 ? b.candidates(cell).reduce(0) { $0 | (1 << $1) } : 0
        }
        let usable = (0..<81).filter { masks[$0] != 0 }
        let seen = peerTable

        let usableSet = CellSet(usable)
        for unit in units {
            let inUnit = unit.map { $0.row * 9 + $0.column }.filter { masks[$0] != 0 }
            for pivotCount in 1...5 {
                for pivots in inUnit.choose(pivotCount) {
                    let pivotSet = CellSet(pivots)
                    let poolSet = pivots.reduce(usableSet) { $0.intersection(CellSet.peers[$1]) }.subtracting(pivotSet)
                    // A group inside one unit has every digit restricted, so it never has a z:
                    // skip pivots whose possible wings all share the pivots' unit.
                    let group = poolSet.union(pivotSet)
                    if CellSet.units.contains(where: { group.isSubset(of: $0) }) { continue }
                    let pool = poolSet.cells
                    var cells: [Int] = []
                    // Grow the set a cell at a time, tracking its digits and which of them have
                    // copies that don't see each other. Adding cells only adds digits and only
                    // unrestricts them, so past 7 digits or with two unrestricted, stop.
                    func add(_ cell: Int, held: Int, loose: Int) -> (held: Int, loose: Int) {
                        var loose = loose
                        for digit in 1...9 where masks[cell] & (1 << digit) != 0 {
                            if cells.contains(where: { masks[$0] & (1 << digit) != 0 && seen[cell][$0] == false }) {
                                loose |= 1 << digit
                            }
                        }
                        return (held | masks[cell], loose)
                    }
                    func grow(held: Int, loose: Int, wings: Int, from start: Int) {
                        guard held.nonzeroBitCount <= 7, loose.nonzeroBitCount <= 1 else { return }
                        if wings >= 2, cells.count >= 4, held.nonzeroBitCount == cells.count, loose != 0 {
                            let z = loose.trailingZeroBitCount
                            let zCells = cells.filter { masks[$0] & (1 << z) != 0 }
                            for target in 0..<81 where cells.contains(target) == false && zCells.allSatisfy({ seen[target][$0] }) {
                                let cell = allCells[target]
                                if b.has(cell, z) { out[cells.count, default: Licensed()].eliminations.insert(Candidate(cell, z)) }
                            }
                        }
                        guard cells.count < 7, start < pool.count else { return }
                        for i in start..<pool.count {
                            let next = add(pool[i], held: held, loose: loose)
                            cells.append(pool[i])
                            grow(held: next.held, loose: next.loose, wings: wings + 1, from: i + 1)
                            cells.removeLast()
                        }
                    }
                    var held = 0, loose = 0
                    for pivot in pivots {
                        (held, loose) = add(pivot, held: held, loose: loose)
                        cells.append(pivot)
                    }
                    grow(held: held, loose: loose, wings: 0, from: 0)
                }
            }
        }
        return out
    }

    /// A set of cells 0...80 (row-major) as bits, for the n-Y-Wing search.
    struct CellSet {
        var low: UInt64 = 0   // cells 0...63
        var high: UInt64 = 0  // cells 64...80

        init(_ cells: [Int] = []) {
            for cell in cells {
                if cell < 64 { low |= 1 << UInt64(cell) } else { high |= 1 << UInt64(cell - 64) }
            }
        }

        func intersection(_ other: CellSet) -> CellSet { var s = self; s.low &= other.low; s.high &= other.high; return s }
        func union(_ other: CellSet) -> CellSet { var s = self; s.low |= other.low; s.high |= other.high; return s }
        func subtracting(_ other: CellSet) -> CellSet { var s = self; s.low &= ~other.low; s.high &= ~other.high; return s }
        func isSubset(of other: CellSet) -> Bool { low & ~other.low == 0 && high & ~other.high == 0 }
        var cells: [Int] { (0..<81).filter { $0 < 64 ? low & (1 << UInt64($0)) != 0 : high & (1 << UInt64($0 - 64)) != 0 } }

        static let peers: [CellSet] = allCells.map { a in CellSet((0..<81).filter { sees(a, allCells[$0]) }) }
        static let units: [CellSet] = Reference.units.map { CellSet($0.map { $0.row * 9 + $0.column }) }
    }

    /// `peerTable[a][b]` says whether cells a and b (0...80, row-major) see each other.
    static let peerTable: [[Bool]] = allCells.map { a in allCells.map { sees(a, $0) } }

    /// Two unconnected {x,y} cells, each seeing one end of a conjugate pair on x: one of them
    /// is y, so cells seeing both lose y.
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_wings.php.
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

// MARK: - Uniqueness

extension Reference {
    /// A rectangle of four empty cells over two boxes, all holding {a, b}, would let a and b
    /// swap. With one solution that can't happen, so the corners' other candidates matter.
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_ur.php.
    static func uniqueRectangle(_ b: Board, type: Int) -> Licensed {
        var out = Licensed()
        for rowPair in Array(0..<9).choose(2) {
            for columnPair in Array(0..<9).choose(2) {
                let corners = rowPair.flatMap { r in columnPair.map { Puzzle.Index(row: r, column: $0) } }
                guard Set(corners.map(box(of:))).count == 2, corners.allSatisfy(b.isEmpty) else { continue }
                let common = corners.map(b.candidates).reduce(Set(1...9)) { $0.intersection($1) }
                for pair in common.sorted().choose(2).map(Set.init) {
                    let exact = corners.filter { b.candidates($0) == pair }
                    let extra = corners.filter { b.candidates($0) != pair }
                    let floorIsSide = exact.count == 2 && (exact[0].row == exact[1].row || exact[0].column == exact[1].column)
                    let singleExtra: Int? = {
                        let extras = Set(extra.map { b.candidates($0).subtracting(pair) })
                        guard extras.count == 1, let only = extras.first, only.count == 1 else { return nil }
                        return only.first
                    }()
                    let shared = units.filter { unit in extra.count == 2 && extra.allSatisfy(unit.contains) }
                    func removeFromPeers(of cells: [Puzzle.Index], _ digit: Int) {
                        for cell in commonPeers(cells) where corners.contains(cell) == false && b.has(cell, digit) {
                            out.eliminations.insert(Candidate(cell, digit))
                        }
                    }

                    switch type {
                    case 1 where exact.count == 3:
                        for digit in pair { out.eliminations.insert(Candidate(extra[0], digit)) }
                    case 2 where floorIsSide:
                        if let x = singleExtra { removeFromPeers(of: extra, x) }
                    case 3 where floorIsSide:
                        let extraDigits = extra.map(b.candidates).reduce(Set<Int>()) { $0.union($1) }.subtracting(pair)
                        for unit in shared {
                            let others = unit.filter { extra.contains($0) == false && b.isEmpty($0) }
                            for size in 1..<max(2, others.count) {
                                for subset in others.choose(size) {
                                    let digits = subset.map(b.candidates).reduce(extraDigits) { $0.union($1) }
                                    guard digits.count == size + 1 else { continue }
                                    for cell in others where subset.contains(cell) == false {
                                        for digit in b.candidates(cell).intersection(digits) {
                                            out.eliminations.insert(Candidate(cell, digit))
                                        }
                                    }
                                }
                            }
                        }
                    case 4 where floorIsSide:
                        for unit in shared {
                            for locked in pair where Set(b.cells(in: unit, with: locked)) == Set(extra) {
                                let other = pair.subtracting([locked]).first!
                                for cell in extra { out.eliminations.insert(Candidate(cell, other)) }
                            }
                        }
                    case 5:
                        let diagonal = extra.count == 2 && extra[0].row != extra[1].row && extra[0].column != extra[1].column
                        if diagonal || extra.count == 3, let x = singleExtra { removeFromPeers(of: extra, x) }
                    default:
                        break
                    }
                }
            }
        }
        return out
    }

    /// Every empty cell bivalue but one trivalue cell, and removing one digit from it leaves
    /// every candidate exactly twice in every unit: with one solution, that digit goes there.
    ///
    /// Source: http://hodoku.sourceforge.net/en/tech_ur.php (BUG+1).
    static func bug(_ b: Board) -> Licensed {
        var out = Licensed()
        let empty = allCells.filter(b.isEmpty)
        let triple = empty.filter { b.candidates($0).count != 2 }
        guard triple.count == 1, b.candidates(triple[0]).count == 3 else { return out }
        let cell = triple[0]
        for digit in b.candidates(cell) {
            let isGrave = units.allSatisfy { unit in
                (1...9).allSatisfy { candidate in
                    b.isPlaced(candidate, in: unit)
                        || unit.filter { b.has($0, candidate) && ($0 != cell || candidate != digit) }.count == 2
                }
            }
            if isGrave { out.placements.insert(Candidate(cell, digit)) }
        }
        return out
    }
}
