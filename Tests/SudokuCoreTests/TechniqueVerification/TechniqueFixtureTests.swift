//
//  TechniqueFixtureTests.swift
//  SudokuCore
//
//  Hand-made boards for shapes the corpus rarely shows: one positive per new technique with
//  its exact eliminations, and near-misses that must not fire, including the three bugs the
//  verification suite found.
//
import Foundation
import Testing
@testable import SudokuCore

/// A hand-made board. Every cell starts with all nine candidates and each fixture narrows only
/// what its pattern needs, so no other instance of the technique can form. Cells are 1-based,
/// matching the r1c1 names in the expectations.
struct Sketch {
    var candidates = Array(repeating: Array(repeating: Set(1...9), count: 9), count: 9)
    var unique = true

    /// Sets a cell's candidates.
    mutating func set(_ row: Int, _ column: Int, _ digits: Set<Int>) {
        candidates[row - 1][column - 1] = digits
    }

    /// Removes `digit` from every cell of `unit` except `keep`, making them its only homes.
    mutating func confine(_ digit: Int, in unit: SudokuUnit, to keep: [(Int, Int)]) {
        let kept = keep.map { Puzzle.Index(row: $0.0 - 1, column: $0.1 - 1) }
        for cell in unit.positions where kept.contains(cell) == false {
            candidates[cell.row][cell.column].remove(digit)
        }
    }

    var state: BoardState {
        BoardState(
            grid: Array(repeating: Array(repeating: 0, count: 9), count: 9),
            pencilMarks: candidates,
            validOptions: Array(repeating: Array(repeating: Set(1...9), count: 9), count: 9),
            assumesUniqueSolution: unique
        )
    }
}

/// A fixture: a sketch, the technique, and the exact eliminations expected (empty for a
/// near-miss that must stay silent).
struct TechniqueFixture: CustomTestStringConvertible, Sendable {
    let name: String
    let technique: HintTechnique
    let state: BoardState
    /// "r1c2#3" names, matching `Reference.Candidate.description`.
    let eliminations: Set<String>
    let placements: Set<String>

    var testDescription: String { name }

    init(_ name: String, _ technique: HintTechnique, eliminations: Set<String> = [], build: (inout Sketch) -> Void) {
        var sketch = Sketch()
        build(&sketch)
        self.name = name
        self.technique = technique
        self.state = sketch.state
        self.eliminations = eliminations
        self.placements = []
    }

    /// A fixture from a real board: 81 digits (0 for empty) and each cell's candidates.
    init(_ name: String, _ technique: HintTechnique, grid: String, candidates: String, unique: Bool = true,
         eliminations: Set<String> = [], placements: Set<String> = []) {
        let values = grid.map { Int(String($0))! }
        let cells = candidates.split(separator: ",", omittingEmptySubsequences: false).map { Set($0.compactMap { Int(String($0)) }) }
        let rows = (0..<9).map { r in Array(values[(r * 9)..<(r * 9 + 9)]) }
        self.name = name
        self.technique = technique
        self.state = BoardState(
            grid: rows,
            pencilMarks: (0..<9).map { r in Array(cells[(r * 9)..<(r * 9 + 9)]) },
            validOptions: Validator.validOptions(for: rows),
            assumesUniqueSolution: unique
        )
        self.eliminations = eliminations
        self.placements = placements
    }

    /// Every other cell of row `row`, as "rRcC#digit" names, skipping `columns`.
    static func restOfRow(_ row: Int, skipping columns: [Int], digits: [Int]) -> Set<String> {
        Set((1...9).filter { columns.contains($0) == false }.flatMap { c in digits.map { "r\(row)c\(c)#\($0)" } })
    }
}

struct TechniqueFixtureTests {
    /// A late state of seed puzzle 176003500… (Hard) that BUG+1 finishes.
    static let bugGrid = "176943582402150690905062400527689300391425800864371259059010730018030905743596128"
    static let bugCandidates = ",,,,,,,,,,38,,,,78,,,37,,38,,78,,,,17,137,,,,,,,,14,14,,,,,,,,67,67,,,,,,,,,,26,,,28,,48,,,46,26,,,27,,47,,46,,,,,,,,,,"
    /// The BUG+1 state with r2c2 changed from {3, 8} to {3, 7}: r3c9 is still the only cell
    /// with three candidates, but no digit taken out of it leaves every candidate twice in every
    /// unit. (The grid rules 7 out of r2c2, so no real board gets here; the shape is the test.)
    static let notGraveCandidates = ",,,,,,,,,,37,,,,78,,,37,,38,,78,,,,17,137,,,,,,,,14,14,,,,,,,,67,67,,,,,,,,,,26,,,28,,48,,,46,26,,,27,,47,,46,,,,,,,,,,"

    static let fixtures: [TechniqueFixture] = [
        // MARK: Crane
        TechniqueFixture("Crane: box pair r1c1/r2c3 joined along row 2 to column pair r2c7/r6c7",
                         .crane, eliminations: ["r6c1#1"]) { s in
            s.confine(1, in: .house(0), to: [(1, 1), (2, 3)])
            s.confine(1, in: .column(6), to: [(2, 7), (6, 7)])
        },
        TechniqueFixture("Crane near-miss: the joined ends don't see each other", .crane) { s in
            s.confine(1, in: .house(0), to: [(1, 1), (2, 3)])
            s.confine(1, in: .column(6), to: [(4, 7), (6, 7)])
        },

        // MARK: n-Y-Wings (pivot r5c5, one wing per pivot digit, all sharing z)
        TechniqueFixture("4-Y-Wing: pivot {1,2,3}, wings {1,4} {2,4} {3,4}", .fourYWing, eliminations: ["r5c6#4"]) { s in
            s.set(5, 5, [1, 2, 3]); s.set(5, 4, [1, 4]); s.set(5, 8, [2, 4]); s.set(6, 6, [3, 4])
        },
        TechniqueFixture("5-Y-Wing: pivot {1,2,3,4}, four wings sharing 5", .fiveYWing, eliminations: ["r5c6#5"]) { s in
            s.set(5, 5, [1, 2, 3, 4]); s.set(5, 4, [1, 5]); s.set(5, 8, [2, 5]); s.set(6, 6, [3, 5]); s.set(4, 4, [4, 5])
        },
        TechniqueFixture("6-Y-Wing: pivot {1-5}, five wings sharing 6", .sixYWing, eliminations: ["r5c6#6"]) { s in
            s.set(5, 5, [1, 2, 3, 4, 5]); s.set(5, 4, [1, 6]); s.set(5, 8, [2, 6]); s.set(6, 6, [3, 6])
            s.set(4, 4, [4, 6]); s.set(6, 4, [5, 6])
        },
        TechniqueFixture("7-Y-Wing: pivot {1-6}, six wings sharing 7", .sevenYWing, eliminations: ["r5c6#7"]) { s in
            s.set(5, 5, [1, 2, 3, 4, 5, 6]); s.set(5, 4, [1, 7]); s.set(5, 8, [2, 7]); s.set(6, 6, [3, 7])
            s.set(4, 4, [4, 7]); s.set(6, 4, [5, 7]); s.set(4, 6, [6, 7])
        },
        // Sudoku Coach's shape without the restriction check: wing cells r5c1 and r1c5 both see
        // the pivot but not each other, so 3 could fill both and nothing is proved. A finder
        // trusting the shape alone would remove 4 from r1c6.
        TechniqueFixture("4-Y-Wing near-miss: a wing digit could repeat", .fourYWing) { s in
            s.set(5, 5, [1, 2]); s.set(5, 1, [1, 3]); s.set(1, 5, [3, 4]); s.set(4, 6, [2, 4])
        },

        // MARK: Unique Rectangles (rows 1-2, columns 1 and 4: boxes 1 and 2, pair {1,2})
        TechniqueFixture("UR type 1: three corners are {1,2}", .uniqueRectangleType1,
                         eliminations: ["r2c4#1", "r2c4#2"]) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2]); s.set(2, 4, [1, 2, 3, 5])
        },
        TechniqueFixture("UR near-miss: corners over four boxes aren't a deadly pattern", .uniqueRectangleType1) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(4, 1, [1, 2]); s.set(4, 4, [1, 2, 3, 5])
        },
        TechniqueFixture("UR near-miss: a puzzle not known to be unique", .uniqueRectangleType1) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2]); s.set(2, 4, [1, 2, 3, 5])
            s.unique = false
        },
        TechniqueFixture("UR type 2: both roof corners add 3", .uniqueRectangleType2,
                         eliminations: TechniqueFixture.restOfRow(2, skipping: [1, 4], digits: [3])) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 3])
        },
        TechniqueFixture("UR type 2 near-miss: the roof corners add different digits", .uniqueRectangleType2) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 5])
        },
        TechniqueFixture("UR type 3: roof extras {3,4} pair with r2c7", .uniqueRectangleType3,
                         eliminations: TechniqueFixture.restOfRow(2, skipping: [1, 4, 7], digits: [3, 4])) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 4]); s.set(2, 7, [3, 4])
        },
        TechniqueFixture("UR type 3 near-miss: r2c7 doesn't match the roof's extras", .uniqueRectangleType3) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 4]); s.set(2, 7, [3, 5])
        },
        TechniqueFixture("UR type 4: 1 only goes in the roof in row 2", .uniqueRectangleType4,
                         eliminations: ["r2c1#2", "r2c4#2"]) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 5])
            s.confine(1, in: .row(1), to: [(2, 1), (2, 4)])
        },
        TechniqueFixture("UR type 4 near-miss: 1 has a third home in row 2", .uniqueRectangleType4) { s in
            s.set(1, 1, [1, 2]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2, 3]); s.set(2, 4, [1, 2, 5])
            s.confine(1, in: .row(1), to: [(2, 1), (2, 4), (2, 7)])
        },
        TechniqueFixture("UR type 5: diagonal corners add 3", .uniqueRectangleType5,
                         eliminations: ["r2c2#3", "r2c3#3", "r1c5#3", "r1c6#3"]) { s in
            s.set(1, 1, [1, 2, 3]); s.set(1, 4, [1, 2]); s.set(2, 1, [1, 2]); s.set(2, 4, [1, 2, 3])
        },

        // MARK: BUG+1 (a real state: every empty cell holds two candidates but r3c9, {1,3,7})
        // 7 is the extra, not the smallest candidate, so a finder that skips the grave check
        // and places the first candidate gets it wrong.
        TechniqueFixture("BUG+1: r3c9 is the only cell with three candidates", .bug,
                         grid: bugGrid, candidates: bugCandidates, placements: ["r3c9#7"]),
        TechniqueFixture("BUG+1 near-miss: a puzzle not known to be unique", .bug,
                         grid: bugGrid, candidates: bugCandidates, unique: false),
        TechniqueFixture("BUG+1 near-miss: one cell with three candidates, but no digit leaves a grave", .bug,
                         grid: bugGrid, candidates: notGraveCandidates),

        // MARK: The bugs the verification suite found
        TechniqueFixture("Pointing near-miss: a lone candidate in a box is a hidden single", .lockedCandidatesPointing) { s in
            s.confine(1, in: .house(0), to: [(1, 1)])
        },
        TechniqueFixture("W-Wing near-miss: matching cells that see each other are a naked pair", .wWing) { s in
            // r4c1 sees r1c1 and r4c5 sees r1c5, but r1c1 and r1c5 share row 1.
            s.set(1, 1, [1, 2]); s.set(1, 5, [1, 2])
            s.confine(1, in: .row(3), to: [(4, 1), (4, 5)])
        },
        // Row 1 holds 1 in columns 2 and 8. Row 4 holds it in column 8 and in fins r4c1 and
        // r4c3, but not in column 2 (sashimi). Column 8 appears in both rows and column 2 in
        // only one, tied with the fin columns, so ranking by frequency picked column 1 and
        // missed the fish.
        TechniqueFixture("Sashimi X-Wing whose core column appears in fewer rows than a fin column",
                         .finnedXWing, eliminations: ["r5c2#1", "r6c2#1"]) { s in
            s.confine(1, in: .row(0), to: [(1, 2), (1, 8)])
            s.confine(1, in: .row(3), to: [(4, 1), (4, 3), (4, 8)])
        },
    ]

    @Test("Hand-made boards: each technique finds exactly the expected eliminations, or nothing",
          arguments: fixtures)
    func fixture(_ fixture: TechniqueFixture) {
        let hint = HintFinder.findHint(for: fixture.technique, in: fixture.state)
        let actions = hint?.actions ?? []
        let found = Set(actions.compactMap { action -> String? in
            if case .ruleOut(let digit) = action.action { return Reference.Candidate(action.position, digit).description }
            return nil
        })
        let placed = Set(actions.compactMap { action -> String? in
            if case .solveAs(let digit) = action.action { return Reference.Candidate(action.position, digit).description }
            return nil
        })
        let licensed = Reference.licensedAll([fixture.technique], in: fixture.state)[fixture.technique]!

        #expect(found == fixture.eliminations, "core eliminates \(found.sorted())")
        #expect(placed == fixture.placements, "core places \(placed.sorted())")
        #expect(Set(licensed.eliminations.map(\.description)) == fixture.eliminations, "reference eliminates \(licensed.eliminations.map(\.description).sorted())")
        #expect(Set(licensed.placements.map(\.description)) == fixture.placements, "reference places \(licensed.placements.map(\.description).sorted())")
    }
}
