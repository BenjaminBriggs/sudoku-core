//
//  TechniqueVerificationTests.swift
//  SudokuCore
//
//  Checks every production technique against the solution and against the definition-level
//  finders in `ReferenceTechniques.swift`, on every state of a corpus of real puzzles.
//
import Foundation
import Testing
@testable import SudokuCore

/// A puzzle with its known solution, taken from the app's bundled seed pools. Most of them
/// stall today's finder, since stall points are where a missed pattern costs a puzzle.
struct CorpusPuzzle: Decodable, Sendable, CustomTestStringConvertible {
    let id: String
    let level: String
    let startingState: [[Int]]
    let solution: [[Int]]

    var testDescription: String { "\(level) \(id.prefix(18))…" }

    static let all: [CorpusPuzzle] = {
        let url = Bundle.module.url(forResource: "technique-corpus", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode([CorpusPuzzle].self, from: Data(contentsOf: url))
    }()

    /// All 60 puzzles take about 5 minutes in a debug build, so by default the first 4 of each
    /// level run. Set `SUDOKU_VERIFY_ALL=1` for the whole corpus; in release
    /// (`swift test -c release -Xswiftc -enable-testing`) that takes about 20 seconds.
    static let selected: [CorpusPuzzle] = {
        if ProcessInfo.processInfo.environment["SUDOKU_VERIFY_ALL"] != nil { return all }
        return Dictionary(grouping: all, by: \.level).values.flatMap { $0.prefix(4) }.sorted { $0.id < $1.id }
    }()
}

/// Seeded generator, so thinned states are the same on every run.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: String) {
        // FNV-1a: String.hashValue changes between processes.
        state = seed.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

struct TechniqueVerificationTests {
    static let techniques = HintTechnique.orderedCases.filter { $0 != .validation && $0 != .unknown }

    /// Every state on the puzzle's solve path, each followed by a copy with about a quarter of
    /// its wrong candidates removed. Thinning reaches patterns the path alone never shows,
    /// while keeping every state consistent with the solution.
    static func states(for puzzle: CorpusPuzzle) -> [BoardState] {
        var rng = SplitMix64(seed: puzzle.id)
        var states: [BoardState] = []
        var state = BoardState.fromGrid(puzzle.startingState)
        while true {
            var thinned = state.pencilMarks
            for r in 0..<9 {
                for c in 0..<9 where state.grid[r][c] == 0 {
                    for digit in thinned[r][c] where digit != puzzle.solution[r][c] && rng.next() % 4 == 0 {
                        thinned[r][c].remove(digit)
                    }
                }
            }
            states.append(state)
            states.append(BoardState(grid: state.grid, pencilMarks: thinned, validOptions: state.validOptions))
            guard let hint = HintFinder.firstHint(in: state), hint.technique != .validation else { break }
            state = state.applying(hint)
        }
        return states
    }

    @Test("Every hint agrees with the solution, matches its technique's definition, and none is missed",
          arguments: CorpusPuzzle.selected)
    func verify(_ puzzle: CorpusPuzzle) {
        var failures: [String] = []
        let solution = puzzle.solution

        for (index, state) in Self.states(for: puzzle).enumerated() {
            for technique in Self.techniques {
                let where_ = "\(technique.rawValue) state \(index)"
                let reference = Reference.licensed(technique, in: state)

                // The reference must itself be sound, or nothing it says can be trusted.
                for c in reference.placements where solution[c.row][c.column] != c.digit {
                    failures.append("reference \(where_): placement \(c) is wrong")
                }
                for c in reference.eliminations where solution[c.row][c.column] == c.digit {
                    failures.append("reference \(where_): elimination \(c) removes the answer")
                }

                guard let hint = HintFinder.findHint(for: technique, in: state) else {
                    if reference.isEmpty == false {
                        let sample = (reference.placements.map(\.description) + reference.eliminations.map(\.description)).sorted().prefix(4)
                        failures.append("missed \(where_): definition licenses \(sample.joined(separator: ", "))")
                    }
                    continue
                }

                for action in hint.actions {
                    let cell = action.position
                    switch action.action {
                    case .solveAs(let digit):
                        let c = Reference.Candidate(cell, digit)
                        if state.grid[cell.row][cell.column] != 0 { failures.append("\(where_): places \(c) on a filled cell") }
                        if solution[cell.row][cell.column] != digit { failures.append("UNSOUND \(where_): places \(c)") }
                        if reference.placements.contains(c) == false { failures.append("mislabelled \(where_): \(c) isn't a \(technique.rawValue) placement") }
                    case .ruleOut(let digit):
                        let c = Reference.Candidate(cell, digit)
                        if state.pencilMarks[cell.row][cell.column].contains(digit) == false { failures.append("\(where_): removes absent \(c)") }
                        if solution[cell.row][cell.column] == digit { failures.append("UNSOUND \(where_): removes answer \(c)") }
                        if reference.eliminations.contains(c) == false { failures.append("mislabelled \(where_): \(c) isn't a \(technique.rawValue) elimination") }
                    case .pencilIn, .clear:
                        failures.append("\(where_): unexpected \(action.debugDescription)")
                    }
                }
                if hint.actions.isEmpty { failures.append("\(where_): hint has no actions") }

                let inconsistencies = hint.reasoning.inconsistencies(in: state)
                if inconsistencies.isEmpty == false {
                    failures.append("\(where_): reasoning disagrees with the board: \(inconsistencies.prefix(2))")
                }
            }
        }

        #expect(failures.isEmpty, "\(failures.count) problems, first: \(failures.prefix(8).joined(separator: " | "))")
    }
}
