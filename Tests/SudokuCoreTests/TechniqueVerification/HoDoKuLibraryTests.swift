//
//  HoDoKuLibraryTests.swift
//  SudokuCore
//
//  Runs the hint finder on HoDoKu's regression test library (reglib-1.3.txt): over a thousand
//  hand-collected candidate grids, each with the one result a technique must give there for the
//  digits it names, and some where a technique must not fire. The library comes with HoDoKu and
//  isn't part of this repository; set SUDOKU_HODOKU_REGLIB to its path (scripts/hodoku/fetch.sh
//  downloads it).
//
//  A grid can hold other instances of the technique for other digits, and the hint finder gives
//  the first it finds. So the library's result is checked against every instance the
//  technique's definition allows there, as `ReferenceTechniques.swift` lists them, and the hint
//  finder's own hint must be one of those.
//
import Foundation
import Testing
@testable import SudokuCore

/// One line of the library: `:technique:candidates:givens:deleted:eliminations:placements:extra`.
struct LibraryCase: Sendable, CustomTestStringConvertible {
    let line: Int
    let code: String
    /// True when the technique must not fire (variant "x").
    let mustNotFire: Bool
    let technique: HintTechnique
    let state: BoardState
    let expected: Set<Move>

    var testDescription: String { "line \(line): \(code) \(technique.rawValue)" }

    /// The library's codes for the techniques the hint finder has. Locked Pairs and Triples are
    /// naked subsets; sashimi and Siamese fish are finned fish; a Dual Kite or Dual Empty
    /// Rectangle is two of them, so the hint finder finds one at a time. Turbot Fish (0403)
    /// covers shapes the hint finder doesn't have, and HoDoKuTests checks the Crane-shaped ones.
    /// The Unique Rectangle variants "with missing candidates" (-2) are left out: a rectangle
    /// here needs both its digits in all four corners.
    static let techniques: [String: HintTechnique] = [
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
        "0800": .xyWing, "0801": .xyzWing, "0803": .wWing,
    ]

    static let path = ProcessInfo.processInfo.environment["SUDOKU_HODOKU_REGLIB"]

    static let all: [LibraryCase] = {
        guard let path, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
            parse(String(line).trimmingCharacters(in: .whitespacesAndNewlines), line: index + 1)
        }
    }()

    static func parse(_ text: String, line: Int) -> LibraryCase? {
        guard text.hasPrefix(":") else { return nil }
        let fields = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 7 else { return nil }
        let parts = fields[1].split(separator: "-").map(String.init)
        guard let technique = techniques[parts[0]] else { return nil }
        if parts[0].hasPrefix("060"), parts.count > 1, parts[1] == "2" { return nil }

        // Givens, with "+" before a digit that was placed rather than given; both count here.
        var digits: [Int] = []
        for char in fields[3] where char != "+" { digits.append(char.wholeNumberValue ?? 0) }
        guard digits.count == 81 else { return nil }
        let grid = (0..<9).map { Array(digits[($0 * 9)..<($0 * 9 + 9)]) }

        func candidates(_ field: String) -> [(digit: Int, row: Int, column: Int)] {
            field.split(separator: " ").compactMap { item in
                let n = item.compactMap(\.wholeNumberValue)
                return n.count == 3 ? (n[0], n[1] - 1, n[2] - 1) : nil
            }
        }
        let valid = Validator.validOptions(for: grid)
        var marks = valid
        for c in candidates(fields[4]) { marks[c.row][c.column].remove(c.digit) }
        let state = BoardState(grid: grid, pencilMarks: marks, validOptions: valid, assumesUniqueSolution: true)

        var expected = candidates(fields[5]).map { Move(place: false, row: $0.row, column: $0.column, digit: $0.digit) }
            + candidates(fields[6]).map { Move(place: true, row: $0.row, column: $0.column, digit: $0.digit) }
        // The library writes BUG+1 as eliminating the cell's other candidates; the hint finder
        // places the digit they leave.
        if technique == .bug, let cell = expected.first?.cell {
            let left = marks[cell / 9][cell % 9].subtracting(expected.map(\.digit))
            if left.count == 1 { expected = [Move(place: true, row: cell / 9, column: cell % 9, digit: left.first!)] }
        }
        return LibraryCase(line: line, code: fields[1], mustNotFire: parts.count > 1 && parts[1] == "x",
                           technique: technique, state: state, expected: Set(expected))
    }
}

struct HoDoKuLibraryTests {
    @Test("Each library case's result is one the hint finder's technique allows, and the hint finder finds it",
          .enabled(if: LibraryCase.path != nil), arguments: LibraryCase.all)
    func libraryCase(_ test: LibraryCase) {
        let licensed = Reference.licensed(test.technique, in: test.state)
        let allowed = Set(licensed.eliminations.map { Move(place: false, row: $0.row, column: $0.column, digit: $0.digit) }
            + licensed.placements.map { Move(place: true, row: $0.row, column: $0.column, digit: $0.digit) })
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

    @Test("The library is read", .enabled(if: LibraryCase.path != nil))
    func libraryIsRead() {
        #expect(LibraryCase.all.count > 500)
    }
}
