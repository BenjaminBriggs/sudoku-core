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
struct CorpusPuzzle: Codable, Sendable, CustomTestStringConvertible {
    let id: String
    let level: String
    let startingState: [[Int]]
    let solution: [[Int]]

    var testDescription: String { "\(level) \(id.prefix(18))…" }

    /// The 60-puzzle fixture corpus.
    static let fixtureCorpus: [CorpusPuzzle] = {
        let url = Bundle.module.url(forResource: "technique-corpus", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode([CorpusPuzzle].self, from: Data(contentsOf: url))
    }()

    /// The fixture corpus, plus in the soak every seed file in `SUDOKU_SOAK_SEEDS` and the
    /// puzzles `SUDOKU_SOAK_GENERATE` makes.
    static let all: [CorpusPuzzle] = {
        guard isSoak, let folder = ProcessInfo.processInfo.environment["SUDOKU_SOAK_SEEDS"] else { return fixtureCorpus }
        struct Seed: Decodable {
            let id: String
            let startingState: [[Int]]
            let solution: [[Int]]
            let difficulty: Difficulty
            struct Difficulty: Decodable { let level: String }
        }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        let seeds = files.filter { $0.hasSuffix(".json") }.sorted().flatMap { file -> [CorpusPuzzle] in
            let url = URL(fileURLWithPath: folder).appendingPathComponent(file)
            let decoded = (try? JSONDecoder().decode([Seed].self, from: Data(contentsOf: url))) ?? []
            return decoded.map {
                CorpusPuzzle(id: $0.id, level: $0.difficulty.level, startingState: $0.startingState, solution: $0.solution)
            }
        }
        let known = Set(fixtureCorpus.map(\.id))
        return fixtureCorpus + seeds.filter { known.contains($0.id) == false }
    }() + GeneratedCorpus.puzzles

    /// The soak tier (`SUDOKU_VERIFY_ALL=1`, best in release with `-c release -Xswiftc
    /// -enable-testing`) checks every corpus puzzle at every state. The per-commit tier checks
    /// one stalling puzzle per level at a sample of states, to stay quick in a debug build.
    static let isSoak = ProcessInfo.processInfo.environment["SUDOKU_VERIFY_ALL"] != nil

    static let selected: [CorpusPuzzle] = {
        if isSoak { return all }
        return Dictionary(grouping: all, by: \.level).values.compactMap(\.first).sorted { $0.id < $1.id }
    }()

    /// The starting grid with one empty cell given a digit its peers allow but the solution
    /// doesn't have: no two givens clash, but there's no solution.
    var unsolvableGrid: [[Int]] {
        var grid = startingState
        let options = Validator.validOptions(for: grid)
        for row in 0..<9 {
            for column in 0..<9 where grid[row][column] == 0 && options[row][column].count >= 3 {
                let wrong: [Int] = options[row][column].sorted().filter { $0 != solution[row][column] }
                grid[row][column] = wrong[0]
                return grid
            }
        }
        return grid
    }

    /// Check every `stride`th state: all of them in the soak, a sample per commit.
    static func stride(perCommit: Int) -> Int { isSoak ? 1 : perCommit }
}

/// A quarter of one puzzle's checked states, so the slices run in parallel.
struct CorpusSlice: Sendable, CustomTestStringConvertible {
    static let parts = 4

    let puzzle: CorpusPuzzle
    let part: Int

    var testDescription: String { "\(puzzle.testDescription) part \(part + 1)/\(Self.parts)" }

    static let selected: [CorpusSlice] = CorpusPuzzle.selected.flatMap { puzzle in
        (0..<parts).map { CorpusSlice(puzzle: puzzle, part: $0) }
    }

    /// The slice's states: every `stride`th state of the puzzle, dealt round the parts.
    func states(stride perCommit: Int) -> [(index: Int, state: BoardState)] {
        let stride = CorpusPuzzle.stride(perCommit: perCommit)
        return TechniqueVerificationTests.states(for: puzzle).enumerated()
            .filter { $0.offset % stride == 0 && ($0.offset / stride) % Self.parts == part }
            .map { ($0.offset, $0.element) }
    }}

/// Seeded generator, so thinned states are the same on every run.
struct SplitMix64: RandomNumberGenerator {
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
        // Every corpus puzzle has one solution, which the uniqueness techniques rely on.
        var state = BoardState.fromGrid(puzzle.startingState, assumingUniqueSolution: true)
        while true {
            var thinned = state.pencilMarks
            for r in 0..<9 {
                for c in 0..<9 where state.grid[r][c] == 0 {
                    // Sorted: a Set's order changes from run to run.
                    for digit in thinned[r][c].sorted() where digit != puzzle.solution[r][c] && rng.next() % 4 == 0 {
                        thinned[r][c].remove(digit)
                    }
                }
            }
            states.append(state)
            states.append(BoardState(grid: state.grid, pencilMarks: thinned, validOptions: state.validOptions, assumesUniqueSolution: true))
            guard let hint = HintFinder.firstHint(in: state), hint.technique != .validation else { break }
            state = state.applying(hint)
        }
        return states
    }

    @Test("Every hint agrees with the solution, matches its technique's definition, and none is missed",
          arguments: CorpusSlice.selected)
    func verify(_ slice: CorpusSlice) {
        var failures: [String] = []
        let solution = slice.puzzle.solution

        for (index, state) in slice.states(stride: 2) {
            let licensed = Reference.licensedAll(Self.techniques, in: state)
            for technique in Self.techniques {
                let where_ = "\(technique.rawValue) state \(index)"
                let reference = licensed[technique]!

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

        if failures.isEmpty == false { SoakFailures.record(slice.puzzle, failures) }
        #expect(failures.isEmpty, "\(failures.count) problems, first: \(failures.prefix(8).joined(separator: " | "))")
    }
}

/// Appends failing puzzles to `SUDOKU_SOAK_FAILURES` (JSON lines), so a soak failure can be
/// turned into a corpus entry and a regression test.
enum SoakFailures {
    private static let lock = NSLock()

    static func record(_ puzzle: CorpusPuzzle, _ problems: [String]) {
        guard let path = ProcessInfo.processInfo.environment["SUDOKU_SOAK_FAILURES"] else { return }
        struct Entry: Encodable {
            let id: String
            let level: String
            let startingState: [[Int]]
            let solution: [[Int]]
            let problems: [String]
        }
        let entry = Entry(id: puzzle.id, level: puzzle.level, startingState: puzzle.startingState,
                          solution: puzzle.solution, problems: Array(problems.prefix(20)))
        guard var line = try? JSONEncoder().encode(entry) else { return }
        line.append(0x0A)
        lock.lock()
        defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: path) == false {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        }
    }
}
