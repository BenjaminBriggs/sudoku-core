//
//  TechniqueLibraryTests.swift
//  SudokuCore
//
//  Technique test cases in HoDoKu's library format, one candidate grid per line with the one
//  result a technique must give there, or a note that it mustn't fire:
//
//    :<technique>:<digits>:<givens>:<deleted candidates>:<eliminations>:<placements>:<extra>
//
//  Givens are 81 characters, with "+" before a digit that was placed rather than given; the
//  uniqueness techniques run only when the givens have one solution.
//  Candidates are <digit><row><column>, separated by spaces, so "436 257" means r3c6 ≠ 4 and
//  r5c7 ≠ 2. The deleted candidates are those the grid allows but the state has ruled out. A
//  technique code with the variant "-x" means the technique mustn't fire.
//
//  Two libraries use it:
//  - ours, Fixtures/technique-library.txt, run on every commit;
//  - HoDoKu's regression test library, reglib-1.3.txt, which comes with HoDoKu and isn't part
//    of this repository: set SUDOKU_HODOKU_REGLIB to its path (scripts/hodoku/fetch.sh downloads
//    it).
//
import Foundation
import Testing
@testable import SudokuCore

struct LibraryCase: Sendable, CustomTestStringConvertible {
    let library: String
    let line: Int
    let code: String
    /// True when the technique must not fire (variant "x").
    let mustNotFire: Bool
    let technique: TechniqueInfo
    let state: BoardState
    let expected: Set<Move>

    var testDescription: String { "\(library) line \(line): \(code) \(technique.rawValue)" }

    /// HoDoKu's codes for the techniques the hint finder has. Locked Pairs and Triples are
    /// naked subsets; sashimi and Siamese fish are finned fish; a Dual Kite or Dual Empty
    /// Rectangle is two of them, so the hint finder finds one at a time. Turbot Fish (0403)
    /// covers shapes the hint finder doesn't have, and HoDoKuTests checks the Crane-shaped ones.
    static let hodokuCodes: [String: TechniqueInfo] = [
        "0000": .nakedSingle, "0002": .hiddenSingle, "0003": .nakedSingle,
        "0100": .lockedCandidatesPointing, "0101": .lockedCandidatesClaiming,
        "0110": .nakedPair, "0111": .nakedTriple,
        "0200": .nakedPair, "0201": .nakedTriple, "0202": .nakedQuad,
        "0210": .hiddenPair, "0211": .hiddenTriple, "0212": .hiddenQuad,
        "0300": .xWing, "0301": .swordfish, "0302": .jellyfish,
        "0310": .finnedXWing, "0311": .finnedSwordfish, "0312": .finnedJellyfish,
        "0320": .finnedXWing, "0321": .finnedSwordfish, "0322": .finnedJellyfish,
        "03111": .finnedSwordfish, "03121": .finnedJellyfish, "03211": .finnedSwordfish, "03221": .finnedJellyfish,
        "0400": .skyscraper, "0401": .twoStringKite, "0402": .emptyRectangle,
        "0404": .twoStringKite, "0405": .emptyRectangle,
        "0600": .uniqueRectangleType1, "0601": .uniqueRectangleType2, "0602": .uniqueRectangleType3,
        "0603": .uniqueRectangleType4, "0604": .uniqueRectangleType5, "0610": .bug,
        "0800": .xyWing, "0801": .xyzWing, "0802": .fourYWing, "0803": .wWing,
    ]

    /// Our codes for the techniques HoDoKu doesn't have. (A 4-Y-Wing is HoDoKu's WXYZ-Wing.)
    static let ownCodes: [String: TechniqueInfo] = [
        "M100": .crane, "M105": .fiveYWing, "M106": .sixYWing, "M107": .sevenYWing,
    ]

    /// The code each technique is written under in our library.
    static let writtenCode: [TechniqueInfo: String] = [
        .nakedSingle: "0003", .hiddenSingle: "0002",
        .lockedCandidatesPointing: "0100", .lockedCandidatesClaiming: "0101",
        .nakedPair: "0200", .nakedTriple: "0201", .nakedQuad: "0202",
        .hiddenPair: "0210", .hiddenTriple: "0211", .hiddenQuad: "0212",
        .xWing: "0300", .swordfish: "0301", .jellyfish: "0302",
        .finnedXWing: "0310", .finnedSwordfish: "0311", .finnedJellyfish: "0312",
        .skyscraper: "0400", .twoStringKite: "0401", .emptyRectangle: "0402", .crane: "M100",
        .uniqueRectangleType1: "0600", .uniqueRectangleType2: "0601", .uniqueRectangleType3: "0602",
        .uniqueRectangleType4: "0603", .uniqueRectangleType5: "0604", .bug: "0610",
        .xyWing: "0800", .xyzWing: "0801", .fourYWing: "0802", .wWing: "0803",
        .fiveYWing: "M105", .sixYWing: "M106", .sevenYWing: "M107",
    ]

    static func load(_ text: String, library: String, codes: [String: TechniqueInfo]) -> [LibraryCase] {
        text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
            parse(line.trimmingCharacters(in: .whitespacesAndNewlines), line: index + 1, library: library, codes: codes)
        }
    }

    static func parse(_ text: String, line: Int, library: String, codes: [String: TechniqueInfo]) -> LibraryCase? {
        guard text.hasPrefix(":") else { return nil }
        let fields = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 7 else { return nil }
        let parts = fields[1].split(separator: "-").map(String.init)
        guard let technique = codes[parts[0]] else { return nil }
        // HoDoKu's Unique Rectangle variants "with missing candidates" (-2): a rectangle here
        // needs both its digits in all four corners.
        if parts[0].hasPrefix("060"), parts.count > 1, parts[1] == "2" { return nil }

        var digits: [Int] = [], given: [Int] = []
        var placed = false
        for char in fields[3] {
            if char == "+" { placed = true; continue }
            let digit = char.wholeNumberValue ?? 0
            digits.append(digit)
            given.append(placed ? 0 : digit)
            placed = false
        }
        guard digits.count == 81 else { return nil }
        let grid = (0..<9).map { Array(digits[($0 * 9)..<($0 * 9 + 9)]) }
        // As on a Board, the uniqueness techniques may run only when the givens alone have one
        // solution.
        let isUnique = Validator.solutionCount(of: (0..<9).map { Array(given[($0 * 9)..<($0 * 9 + 9)]) }).isUnique

        func candidates(_ field: String) -> [(digit: Int, row: Int, column: Int)] {
            field.split(separator: " ").compactMap { item in
                let n = item.compactMap(\.wholeNumberValue)
                return n.count == 3 ? (n[0], n[1] - 1, n[2] - 1) : nil
            }
        }
        let valid = Validator.validOptions(for: grid)
        var marks = valid
        for c in candidates(fields[4]) { marks[c.row][c.column].remove(c.digit) }
        let state = BoardState(grid: grid, pencilMarks: marks, validOptions: valid, assumesUniqueSolution: isUnique)

        var expected = candidates(fields[5]).map { Move(place: false, row: $0.row, column: $0.column, digit: $0.digit) }
            + candidates(fields[6]).map { Move(place: true, row: $0.row, column: $0.column, digit: $0.digit) }
        // HoDoKu writes BUG+1 as eliminating the cell's other candidates; the hint finder places
        // the digit they leave.
        if technique == .bug, let cell = expected.first?.cell, expected.allSatisfy({ $0.isPlacement == false }) {
            let left = marks[cell / 9][cell % 9].subtracting(expected.map(\.digit))
            if left.count == 1 { expected = [Move(place: true, row: cell / 9, column: cell % 9, digit: left.first!)] }
        }
        return LibraryCase(library: library, line: line, code: fields[1], mustNotFire: parts.count > 1 && parts[1] == "x",
                           technique: technique, state: state, expected: Set(expected))
    }

    /// `state` as a library line: `technique` must give `expected` there, or with `mustNotFire`,
    /// nothing. `startingState` tells given digits from placed ones.
    static func line(_ technique: TechniqueInfo, digits: [Int], state: BoardState, startingState: [[Int]],
                     expected: Set<Move>, mustNotFire: Bool = false) -> String {
        let givens = (0..<81).map { i -> String in
            let value = state.grid[i / 9][i % 9]
            if value == 0 { return "." }
            return startingState[i / 9][i % 9] == value ? "\(value)" : "+\(value)"
        }.joined()
        let valid = Validator.validOptions(for: state.grid)
        var deleted: [String] = []
        for r in 0..<9 {
            for c in 0..<9 where state.grid[r][c] == 0 {
                for digit in valid[r][c].subtracting(state.pencilMarks[r][c]).sorted() { deleted.append("\(digit)\(r + 1)\(c + 1)") }
            }
        }
        func list(_ moves: [Move]) -> String {
            moves.sorted().map { "\($0.digit)\($0.cell / 9 + 1)\($0.cell % 9 + 1)" }.joined(separator: " ")
        }
        let code = writtenCode[technique]! + (mustNotFire ? "-x" : "")
        return ":\(code):\(digits.sorted().map(String.init).joined()):\(givens):\(deleted.joined(separator: " "))"
            + ":\(list(expected.filter { $0.isPlacement == false })):\(list(expected.filter(\.isPlacement))):"
    }

    // MARK: The libraries

    static let ownURL = HoDoKu.repository.appendingPathComponent("Tests/SudokuCoreTests/Fixtures/technique-library.txt")

    static let own: [LibraryCase] = {
        guard let url = Bundle.module.url(forResource: "technique-library", withExtension: "txt", subdirectory: "Fixtures"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return load(text, library: "ours", codes: hodokuCodes.merging(ownCodes, uniquingKeysWith: { a, _ in a }))
    }()

    static let reglibPath = ProcessInfo.processInfo.environment["SUDOKU_HODOKU_REGLIB"]

    static let hodoku: [LibraryCase] = {
        guard let reglibPath, let text = try? String(contentsOfFile: reglibPath, encoding: .utf8) else { return [] }
        return load(text, library: "reglib", codes: hodokuCodes)
    }()

    /// Every placement and elimination the technique's definition allows in the case's grid.
    var allowed: Set<Move> {
        let licensed = Reference.licensed(technique, in: state)
        return Set(licensed.eliminations.map { Move(place: false, row: $0.row, column: $0.column, digit: $0.digit) }
            + licensed.placements.map { Move(place: true, row: $0.row, column: $0.column, digit: $0.digit) })
    }
}

struct TechniqueLibraryTests {
    /// Our cases each have one instance of their technique, so the hint finder's hint must be
    /// part of the expected result.
    @Test("Each case in our technique library gives the hint finder the result recorded", arguments: LibraryCase.own)
    func ownCase(_ test: LibraryCase) {
        let hint = HintFinder.findHint(for: test.technique, in: test.state)
        if test.mustNotFire {
            #expect(hint == nil, "\(test.technique.rawValue) fired where it mustn't: \(hint.map { Set($0.actions.compactMap(Move.init)).sorted() } ?? [])")
            return
        }
        guard let hint else {
            Issue.record("\(test.technique.rawValue) found nothing; expected \(test.expected.sorted())")
            return
        }
        let moves = Set(hint.actions.compactMap(Move.init))
        #expect(moves.isEmpty == false && moves.isSubset(of: test.expected),
                "the hint finder gives \(moves.sorted()); expected \(test.expected.sorted())")
        #expect(test.expected.isSubset(of: test.allowed),
                "expected \(test.expected.sorted()); the definition allows \(test.allowed.sorted())")
    }

    @Test("Our technique library is read") func ownLibraryIsRead() {
        #expect(LibraryCase.own.isEmpty == false)
    }
}

/// HoDoKu's library promises one result only for the digits a case names, and a grid can hold
/// other instances of the technique, of which the hint finder gives the first it finds. So the
/// library's result is checked against every instance the technique's definition allows there,
/// as `ReferenceTechniques.swift` lists them, and the hint finder's hint must be one of those.
struct HoDoKuLibraryTests {
    @Test("Each HoDoKu library case's result is one the technique allows, and the hint finder finds it",
          .enabled(if: LibraryCase.reglibPath != nil), arguments: LibraryCase.hodoku)
    func hodokuCase(_ test: LibraryCase) {
        let allowed = test.allowed
        let hint = HintFinder.findHint(for: test.technique, in: test.state)
        if test.mustNotFire {
            #expect(hint == nil, "\(test.technique.rawValue) fired where the library says it mustn't")
            #expect(allowed.isEmpty, "the definition allows \(allowed.sorted()) where the library says nothing")
            return
        }
        #expect(test.expected.isSubset(of: allowed),
                "the library expects \(test.expected.sorted()); the definition allows \(allowed.sorted())")
        guard let hint else {
            Issue.record("\(test.technique.rawValue) found nothing; the library expects \(test.expected.sorted())")
            return
        }
        let moves = Set(hint.actions.compactMap(Move.init))
        #expect(moves.isEmpty == false && moves.isSubset(of: allowed),
                "the hint finder gives \(moves.sorted()); the definition allows \(allowed.sorted())")
    }

    @Test("HoDoKu's library is read", .enabled(if: LibraryCase.reglibPath != nil))
    func libraryIsRead() {
        #expect(LibraryCase.hodoku.count > 500)
    }
}
