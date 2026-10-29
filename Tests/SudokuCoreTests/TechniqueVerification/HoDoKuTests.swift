//
//  HoDoKuTests.swift
//  SudokuCore
//
//  Checks every hint against HoDoKu (https://github.com/wyzelli/HoDoKu), an independent
//  solver, on every state of the corpus. HoDoKu is GPL and isn't part of this repository;
//  scripts/hodoku/README.md explains how to install it and run these tests against it. Without
//  it, each commit compares against HoDoKu's findings recorded in Fixtures/hodoku.json.
//
//  At each state, for each technique the two share:
//  - wherever HoDoKu finds the technique, the hint finder must too;
//  - every placement and elimination the hint finder makes must be one HoDoKu also reaches,
//    under that technique or another.
//  HoDoKu has every technique here except the 4- to 7-Y-Wings, which only the reference
//  finders check.
//
import Foundation
import Synchronization
import Testing
@testable import SudokuCore

/// A placement or an elimination, packed into one number for compact fixtures.
struct Move: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let raw: Int

    init(place: Bool, row: Int, column: Int, digit: Int) {
        raw = (place ? 729 : 0) + (row * 9 + column) * 9 + digit - 1
    }

    init?(_ action: HintAction) {
        switch action.action {
        case .solveAs(let digit): self.init(place: true, row: action.position.row, column: action.position.column, digit: digit)
        case .ruleOut(let digit): self.init(place: false, row: action.position.row, column: action.position.column, digit: digit)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws { raw = try decoder.singleValueContainer().decode(Int.self) }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    var isPlacement: Bool { raw >= 729 }
    var cell: Int { (raw % 729) / 9 }
    var digit: Int { raw % 9 + 1 }
    var description: String { "r\(cell / 9 + 1)c\(cell % 9 + 1)\(isPlacement ? "=" : "≠")\(digit)" }
    static func < (a: Move, b: Move) -> Bool { a.raw < b.raw }
}

/// One step HoDoKu reports.
struct HoDoKuStep: Sendable {
    /// HoDoKu's short name for the technique, as `java -jar HoDoKu.jar /lt` lists them.
    let type: String
    let moves: Set<Move>
    let text: String
}

/// What HoDoKu finds at one state, in the hint finder's terms.
struct HoDoKuFindings: Codable, Sendable {
    /// For each of our techniques, the moves HoDoKu's steps of that technique make, after the
    /// differences of definition in `HoDoKu.findings`.
    var licensed: [String: [Move]]
    /// Every move HoDoKu makes here with any technique, chains and loops included.
    var reached: [Move]
    /// HoDoKu's own BUG+1 search threw here, so it gives no verdict on BUG+1.
    var bugUnknown: Bool
}

enum HoDoKu {
    /// The HoDoKu.jar to run, from `SUDOKU_HODOKU_JAR`.
    static let jar = ProcessInfo.processInfo.environment["SUDOKU_HODOKU_JAR"]
    static let isAvailable = jar != nil

    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let driver = repository.appendingPathComponent("scripts/hodoku/FindAll.java")

    /// HoDoKu's types and the techniques they correspond to. A full house is the hint
    /// finder's naked single; HoDoKu's Locked Pairs and Triples are naked subsets.
    static let techniques: [String: [TechniqueInfo]] = [
        "fh": [.nakedSingle], "n1": [.nakedSingle], "h1": [.hiddenSingle],
        "lc1": [.lockedCandidatesPointing], "lc2": [.lockedCandidatesClaiming],
        "n2": [.nakedPair], "l2": [.nakedPair], "n3": [.nakedTriple], "l3": [.nakedTriple], "n4": [.nakedQuad],
        "h2": [.hiddenPair], "h3": [.hiddenTriple], "h4": [.hiddenQuad],
        "bf2": [.xWing], "bf3": [.swordfish], "bf4": [.jellyfish],
        "fbf2": [.finnedXWing], "sbf2": [.finnedXWing], "fbf3": [.finnedSwordfish], "sbf3": [.finnedSwordfish],
        "fbf4": [.finnedJellyfish], "sbf4": [.finnedJellyfish],
        "sk": [.skyscraper], "2sk": [.twoStringKite], "er": [.emptyRectangle],
        "w": [.wWing], "xy": [.xyWing], "xyz": [.xyzWing],
        "u1": [.uniqueRectangleType1], "u2": [.uniqueRectangleType2], "u3": [.uniqueRectangleType3],
        "u4": [.uniqueRectangleType4], "u5": [.uniqueRectangleType5], "bug1": [.bug],
    ]

    /// The techniques compared: all but the n-Y-Wings, which HoDoKu doesn't have.
    static let compared = TechniqueVerificationTests.techniques
        .filter { [.fourYWing, .fiveYWing, .sixYWing, .sevenYWing].contains($0) == false }

    // MARK: Running HoDoKu

    /// The driver exited with `status`; `errors` is the end of what it printed to stderr.
    enum Failure: Error { case exited(status: Int32, errors: String) }

    /// Runs the driver in `mode` on `lines`, split over a few JVMs at once.
    static func run(_ mode: String, _ lines: [String]) throws -> [String] {
        let parts = max(1, min(8, lines.count / 200))
        let chunks = (0..<parts).map { part in lines.enumerated().filter { $0.offset % parts == part }.map(\.element) }
        let results = Mutex<[Result<[String], Error>]>(Array(repeating: .success([]), count: parts))
        DispatchQueue.concurrentPerform(iterations: parts) { part in
            let result = Result { try runOnce(mode, chunks[part]) }
            results.withLock { $0[part] = result }
        }
        return try results.withLock { $0 }.flatMap { try $0.get() }
    }

    private static func runOnce(_ mode: String, _ lines: [String]) throws -> [String] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("sudoku-hodoku-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("in.tsv"), output = folder.appendingPathComponent("out.tsv")
        let errors = folder.appendingPathComponent("err.txt")
        try (lines.joined(separator: "\n") + "\n").write(to: input, atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        FileManager.default.createFile(atPath: errors.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // HoDoKu keeps its settings in java.io.tmpdir; give each run a folder of its own.
        // HoDoKu's step ordering breaks the comparator contract on some states, which TimSort
        // throws on; the legacy merge sort doesn't check, and the order doesn't matter here.
        process.arguments = ["java", "-Xmx2g", "-Djava.awt.headless=true", "-Djava.io.tmpdir=\(folder.path)",
                             "-Duser.home=\(folder.path)", "-Djava.util.Arrays.useLegacyMergeSort=true",
                             "-cp", jar!, driver.path, mode]
        process.standardInput = try FileHandle(forReadingFrom: input)
        process.standardOutput = try FileHandle(forWritingTo: output)
        // HoDoKu's own messages go here too, so keep only the end, where a stack trace would be.
        process.standardError = try FileHandle(forWritingTo: errors)
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let printed = (try? String(contentsOf: errors, encoding: .utf8)) ?? ""
            throw Failure.exited(status: process.terminationStatus,
                                 errors: printed.split(separator: "\n").suffix(30).joined(separator: "\n"))
        }
        return try String(contentsOf: output, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    /// HoDoKu's findings at each keyed state.
    static func findings(for states: [(key: String, state: BoardState)]) throws -> [String: HoDoKuFindings] {
        let (steps, bugFailed) = try steps(for: states)
        var out: [String: HoDoKuFindings] = [:]
        for (key, state) in states {
            out[key] = findings(steps[key] ?? [], bugFailed: bugFailed.contains(key), in: state)
        }
        return out
    }

    /// Every step HoDoKu finds at each keyed state, and the states where its BUG+1 search threw.
    static func steps(for states: [(key: String, state: BoardState)]) throws -> (steps: [String: [HoDoKuStep]], bugFailed: Set<String>) {
        let lines = states.map { key, state in
            let grid = state.grid.flatMap { $0 }.map(String.init).joined()
            return "\(key)\t\(grid)\t\(state.candidateStrings().joined(separator: ","))"
        }
        var steps: [String: [HoDoKuStep]] = [:]
        var bugFailed: Set<String> = []
        for line in try run("states", lines) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2, fields[1] != "END" else { continue }
            if fields[1] == "bug1-error" { bugFailed.insert(fields[0]); continue }
            func moves(_ list: String, place: Bool) -> [Move] {
                list.split(separator: ";").map { item in
                    let n = item.split(separator: " ").map { Int($0)! }
                    return Move(place: place, row: n[0], column: n[1], digit: n[2])
                }
            }
            let step = HoDoKuStep(type: fields[1], moves: Set(moves(fields[2], place: false) + moves(fields[3], place: true)), text: fields[4])
            steps[fields[0], default: []].append(step)
        }
        return (steps, bugFailed)
    }

    /// HoDoKu's solution count for each keyed grid, stopping at 2, with the solution when
    /// there is just one.
    static func solutions(for grids: [(key: String, grid: [[Int]])]) throws -> [String: (count: Int, solution: [[Int]]?)] {
        var out: [String: (count: Int, solution: [[Int]]?)] = [:]
        let lines = grids.map { "\($0.key)\t\($0.grid.flatMap { $0 }.map(String.init).joined())" }
        for line in try run("puzzles", lines) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3, let count = Int(fields[1]) else { continue }
            let digits = fields[2].compactMap { $0.wholeNumberValue }
            out[fields[0]] = (count, digits.count == 81 ? (0..<9).map { Array(digits[($0 * 9)..<($0 * 9 + 9)]) } : nil)
        }
        return out
    }

    /// HoDoKu's own rating of each keyed grid, with its default settings: nil where HoDoKu can't
    /// solve it.
    static func ratings(for grids: [(key: String, grid: [[Int]])]) throws -> [String: (score: Int, level: HoDoKuLevel)?] {
        var out: [String: (score: Int, level: HoDoKuLevel)?] = [:]
        let lines = grids.map { "\($0.key)\t\($0.grid.flatMap { $0 }.map(String.init).joined())" }
        for line in try run("rate", lines) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4, let score = Int(fields[2]) else { continue }
            let level = HoDoKuLevel(rawValue: fields[3].lowercased())
            out[fields[0]] = fields[1] == "1" ? level.map { (score, $0) } : .some(nil)
        }
        return out
    }

    // MARK: Differences of definition

    /// HoDoKu's steps at `state` in the hint finder's terms. Where the two define a technique
    /// differently on purpose, HoDoKu's step is dropped or trimmed:
    /// - a hidden single in a cell with one candidate is the hint finder's naked single;
    /// - a fish with a base line holding one candidate is a hidden single, not a fish;
    /// - a skyscraper, kite or turbot fish never eliminates from its own cells, since each such
    ///   elimination is a locked-candidates one;
    /// - a W-Wing's two cells can't see each other, since then they're a naked pair;
    /// - BUG+1 needs every other empty cell to hold exactly two candidates, and places the
    ///   digit HoDoKu's eliminations leave;
    /// - a turbot fish with one strong link in a box and the other in a line is a Crane.
    static func findings(_ steps: [HoDoKuStep], bugFailed: Bool, in state: BoardState) -> HoDoKuFindings {
        var licensed: [String: Set<Move>] = [:]
        var reached = allMoves(of: steps)
        for step in steps {
            let (targets, moves) = interpret(step, in: state)
            reached.formUnion(moves)
            for technique in targets { licensed[technique.rawValue, default: []].formUnion(moves) }
        }
        return HoDoKuFindings(licensed: licensed.mapValues { $0.sorted() }, reached: reached.sorted(), bugUnknown: bugFailed)
    }

    private static func allMoves(of steps: [HoDoKuStep]) -> Set<Move> {
        steps.reduce(into: Set<Move>()) { $0.formUnion($1.moves) }
    }

    /// One HoDoKu step in the hint finder's terms: the techniques it counts as, after the
    /// differences of definition above, and the moves it makes.
    static func interpret(_ step: HoDoKuStep, in state: BoardState) -> (targets: [TechniqueInfo], moves: Set<Move>) {
        var moves = step.moves
        var targets = techniques[step.type] ?? []
        switch step.type {
        case "h1":
            if let move = moves.first, candidateCount(move.cell, state) == 1 { targets = [] }
        case "bf2", "bf3", "bf4", "fbf2", "fbf3", "fbf4", "sbf2", "sbf3", "sbf4":
            let words = step.text.split(separator: ":")[1].split(separator: " ")
            let digit = Int(words[0])!, base = words[1]
            let lines = base.dropFirst().compactMap(\.wholeNumberValue)
            if lines.contains(where: { homes(of: digit, in: line(base.first!, $0 - 1), state).count < 2 }) { targets = [] }
        case "sk", "2sk", "tf":
            let own = Set(cells(in: String(step.text.split(separator: "=>")[0])).map { $0.row * 9 + $0.column })
            let trimmed = moves.filter { own.contains($0.cell) == false }
            if step.type == "tf", isCrane(step, state) { targets.append(.crane) }
            if trimmed.isEmpty { targets = [] }
            if targets.isEmpty == false { moves = trimmed }
        case "w":
            let pair = cells(in: String(step.text.split(separator: " ")[3]))
            if pair.count == 2, sees(pair[0], pair[1]) { targets = [] }
        case "bug1":
            guard let cell = moves.first?.cell else { break }
            let removed = Set(moves.map(\.digit))
            let left = state.pencilMarks[cell / 9][cell % 9].subtracting(removed)
            if let digit = left.first, left.count == 1 {
                moves.insert(Move(place: true, row: cell / 9, column: cell % 9, digit: digit))
            }
            let strict = (0..<81).allSatisfy { i in
                i == cell || state.grid[i / 9][i % 9] != 0 || candidateCount(i, state) == 2
            }
            if strict == false { targets = [] }
            moves = moves.filter(\.isPlacement)
        default:
            break
        }
        return (targets, moves)
    }

    /// Where HoDoKu, by its own definition, doesn't look for a hint the hint finder makes:
    /// - its Unique Rectangle type 4 takes b out of the two corners only when a is missing from
    ///   every cell that sees both, where the usual definition needs a confined in just one
    ///   unit they share;
    /// - its Unique Rectangle type 3 leaves every cell holding a or b out of the subset.
    static func isHoDoKuGap(_ hint: HintStep, in state: BoardState) -> Bool {
        let reasoning = hint.reasoning
        switch hint.technique {
        case .uniqueRectangleType4:
            guard let extras = reasoning.components.first(where: { $0.role == .fin })?.cells.map(\.position),
                  extras.count == 2, let locked = reasoning.focusDigits.first
            else { return false }
            let corners = Set(reasoning.components.first(where: { $0.role == .base })?.cells.map(\.position) ?? [])
            return (0..<81).map { Puzzle.Index(row: $0 / 9, column: $0 % 9) }.contains { cell in
                corners.contains(cell) == false && sees(cell, extras[0]) && sees(cell, extras[1])
                    && state.grid[cell.row][cell.column] == 0 && state.pencilMarks[cell.row][cell.column].contains(locked)
            }
        case .uniqueRectangleType3:
            let pair = Set(reasoning.focusDigits.prefix(2))
            return reasoning.components.filter { $0.role == .subset }.flatMap(\.cells)
                .contains { state.pencilMarks[$0.position.row][$0.position.column].isDisjoint(with: pair) == false }
        default:
            return false
        }
    }

    /// Ways the hint finder and HoDoKu disagree at `state`, none expected.
    static func differences(at state: BoardState, _ findings: HoDoKuFindings) -> [String] {
        let reached = Set(findings.reached)
        var out: [String] = []
        for technique in compared {
            let licensed = Set(findings.licensed[technique.rawValue] ?? [])
            guard let hint = HintFinder.findHint(for: technique, in: state) else {
                if licensed.isEmpty == false {
                    out.append("\(technique.rawValue): HoDoKu finds \(licensed.sorted().prefix(6)), the hint finder nothing")
                }
                continue
            }
            let moves = Set(hint.actions.compactMap(Move.init))
            if moves.isSubset(of: licensed) || moves.isSubset(of: reached) { continue }
            if technique == .bug, findings.bugUnknown { continue }
            if isHoDoKuGap(hint, in: state) { continue }
            out.append("\(technique.rawValue): HoDoKu reaches none of \(moves.subtracting(reached).sorted().prefix(6))")
        }
        return out
    }

    // MARK: Helpers

    /// Cells in HoDoKu's notation, expanding groups like r23c6 into r2c6 and r3c6.
    static func cells(in text: String) -> [Puzzle.Index] {
        var out: [Puzzle.Index] = []
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            guard chars[i] == "r", i + 1 < chars.count, chars[i + 1].isNumber else { i += 1; continue }
            var j = i + 1
            var rows: [Int] = []
            while j < chars.count, let d = chars[j].wholeNumberValue { rows.append(d - 1); j += 1 }
            guard j < chars.count, chars[j] == "c" else { i = j; continue }
            j += 1
            var columns: [Int] = []
            while j < chars.count, let d = chars[j].wholeNumberValue { columns.append(d - 1); j += 1 }
            for r in rows { for c in columns { out.append(Puzzle.Index(row: r, column: c)) } }
            i = j
        }
        return out
    }

    static func line(_ kind: Character, _ n: Int) -> [Puzzle.Index] {
        (0..<9).map { kind == "r" ? Puzzle.Index(row: n, column: $0) : Puzzle.Index(row: $0, column: n) }
    }

    static func box(of cell: Puzzle.Index) -> [Puzzle.Index] {
        let r = cell.row / 3 * 3, c = cell.column / 3 * 3
        return (0..<9).map { Puzzle.Index(row: r + $0 / 3, column: c + $0 % 3) }
    }

    static func homes(of digit: Int, in unit: [Puzzle.Index], _ state: BoardState) -> Set<Puzzle.Index> {
        Set(unit.filter { state.grid[$0.row][$0.column] == 0 && state.pencilMarks[$0.row][$0.column].contains(digit) })
    }

    static func candidateCount(_ cell: Int, _ state: BoardState) -> Int { state.pencilMarks[cell / 9][cell % 9].count }

    static func sees(_ a: Puzzle.Index, _ b: Puzzle.Index) -> Bool {
        a != b && (a.row == b.row || a.column == b.column || (a.row / 3 == b.row / 3 && a.column / 3 == b.column / 3))
    }

    /// A turbot fish (a =d= b -d- c =d= e) whose strong links are one a box and one a line.
    static func isCrane(_ step: HoDoKuStep, _ state: BoardState) -> Bool {
        let words = step.text.split(separator: ":")[1].split(separator: " ")
        guard words.count >= 8, let digit = Int(words[0]) else { return false }
        let chain = [words[1], words[3], words[5], words[7]].compactMap { cells(in: String($0)).first }
        guard chain.count == 4 else { return false }
        func kinds(_ a: Puzzle.Index, _ b: Puzzle.Index) -> Set<String> {
            var out: Set<String> = []
            if homes(of: digit, in: line("r", a.row), state) == [a, b] || homes(of: digit, in: line("c", a.column), state) == [a, b] {
                out.insert("line")
            }
            if homes(of: digit, in: box(of: a), state) == [a, b] { out.insert("box") }
            return out
        }
        let first = kinds(chain[0], chain[1]), second = kinds(chain[2], chain[3])
        return (first.contains("box") && second.contains("line")) || (first.contains("line") && second.contains("box"))
    }
}

// MARK: - Recorded findings

/// HoDoKu's findings at the per-commit corpus states, so every commit compares against HoDoKu
/// without Java. `SUDOKU_UPDATE_HODOKU_FIXTURE=1` with `SUDOKU_HODOKU_JAR` rewrites it.
struct HoDoKuFixture: Codable {
    struct RecordedState: Codable, Sendable, CustomTestStringConvertible {
        let key: String
        let grid: String
        let candidates: [String]
        let findings: HoDoKuFindings

        var testDescription: String { key }

        var state: BoardState {
            let digits = grid.compactMap(\.wholeNumberValue)
            let rows = (0..<9).map { Array(digits[($0 * 9)..<($0 * 9 + 9)]) }
            let marks = (0..<9).map { r in (0..<9).map { c in Set(candidates[r * 9 + c].compactMap(\.wholeNumberValue)) } }
            return BoardState(grid: rows, pencilMarks: marks, validOptions: Validator.validOptions(for: rows), assumesUniqueSolution: true)
        }
    }

    /// The HoDoKu release the findings came from.
    let hodoku: String
    let states: [RecordedState]

    static let fileURL = HoDoKu.repository.appendingPathComponent("Tests/SudokuCoreTests/Fixtures/hodoku.json")

    static let recorded: [RecordedState] = {
        guard let url = Bundle.module.url(forResource: "hodoku", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url),
              let fixture = try? JSONDecoder().decode(HoDoKuFixture.self, from: data)
        else { return [] }
        return fixture.states
    }()

    /// The puzzles recorded: the first corpus puzzle of each level, at every state.
    static var puzzles: [CorpusPuzzle] {
        Dictionary(grouping: CorpusPuzzle.fixtureCorpus, by: \.level).values.compactMap(\.first).sorted { $0.id < $1.id }
    }
}

extension BoardState {
    /// Each cell's candidates as a string of digits, or `filled(value)` for a filled cell.
    func candidateStrings(filled: (Int) -> String = { _ in "" }) -> [String] {
        var out: [String] = []
        for row in 0..<9 {
            for column in 0..<9 {
                let value: Int = grid[row][column]
                let digits: [Int] = pencilMarks[row][column].sorted()
                out.append(value == 0 ? digits.map(String.init).joined() : filled(value))
            }
        }
        return out
    }
}

/// Every state of `puzzles`, keyed by puzzle and index.
func keyedStates(_ puzzles: [CorpusPuzzle]) -> [(key: String, state: BoardState)] {
    let all = Mutex<[[(key: String, state: BoardState)]]>(Array(repeating: [], count: puzzles.count))
    DispatchQueue.concurrentPerform(iterations: puzzles.count) { i in
        let states = TechniqueVerificationTests.states(for: puzzles[i]).enumerated().map { ("\(puzzles[i].id.prefix(24))-\($0.offset)", $0.element) }
        all.withLock { $0[i] = states }
    }
    return all.withLock { $0 }.flatMap { $0 }
}

struct HoDoKuTests {
    @Test("Every hint agrees with HoDoKu's recorded findings", arguments: HoDoKuFixture.recorded)
    func recorded(_ recorded: HoDoKuFixture.RecordedState) {
        let differences = HoDoKu.differences(at: recorded.state, recorded.findings)
        #expect(differences.isEmpty, "\(differences)")
    }

    @Test("HoDoKu's findings are recorded") func fixtureExists() {
        #expect(HoDoKuFixture.recorded.isEmpty == false)
    }

    @Test("Every hint agrees with HoDoKu, on every state of every corpus puzzle", .enabled(if: HoDoKu.isAvailable))
    func live() throws {
        let puzzles = CorpusPuzzle.isSoak ? CorpusPuzzle.all : CorpusPuzzle.fixtureCorpus
        let states = keyedStates(puzzles)
        let (steps, bugFailed) = try HoDoKu.steps(for: states)
        let findings = Dictionary(uniqueKeysWithValues: states.map { key, state in
            (key, HoDoKu.findings(steps[key] ?? [], bugFailed: bugFailed.contains(key), in: state))
        })
        let failures = Mutex<[String]>([])
        DispatchQueue.concurrentPerform(iterations: states.count) { i in
            let (key, state) = states[i]
            let differences = HoDoKu.differences(at: state, findings[key]!)
            if differences.isEmpty == false {
                let candidates = state.candidateStrings { "[\($0)]" }.joined(separator: ",")
                failures.withLock { $0.append("\(key): \(differences) at \(candidates)") }
            }
        }
        let found = failures.withLock { $0 }.sorted()
        #expect(found.isEmpty, "\(found.count) of \(states.count) states differ: \(found.prefix(20))")

        if ProcessInfo.processInfo.environment["SUDOKU_UPDATE_HODOKU_FIXTURE"] != nil {
            let recordedKeys = Set(keyedStates(HoDoKuFixture.puzzles).map(\.key))
            let recorded = states.filter { recordedKeys.contains($0.key) }.map { key, state in
                HoDoKuFixture.RecordedState(
                    key: key,
                    grid: state.grid.flatMap { $0 }.map(String.init).joined(),
                    candidates: state.candidateStrings(),
                    findings: findings[key]!)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let name = ProcessInfo.processInfo.environment["SUDOKU_HODOKU_VERSION"] ?? URL(fileURLWithPath: HoDoKu.jar!).lastPathComponent
            try encoder.encode(HoDoKuFixture(hodoku: name, states: recorded)).write(to: HoDoKuFixture.fileURL)
        }
        if ProcessInfo.processInfo.environment["SUDOKU_UPDATE_TECHNIQUE_LIBRARY"] != nil {
            try writeLibrary(puzzles: puzzles, states: states, steps: steps)
        }
    }

    /// Rewrites the generated part of our technique library: corpus states where HoDoKu finds
    /// exactly one instance of a technique and the hint finder's hint for it is part of that
    /// instance. Up to six cases per technique, from different puzzles, taking states on a solve
    /// path before thinned ones. Hand-made cases, after the "# Hand-made cases" line, are kept.
    func writeLibrary(puzzles: [CorpusPuzzle], states: [(key: String, state: BoardState)], steps: [String: [HoDoKuStep]]) throws {
        let byPrefix = Dictionary(puzzles.map { (String($0.id.prefix(24)), $0) }, uniquingKeysWith: { a, _ in a })
        let ordered = states.filter { Int($0.key.split(separator: "-").last!)! % 2 == 0 }
            + states.filter { Int($0.key.split(separator: "-").last!)! % 2 == 1 }
        var lines: [String] = []
        for technique in TechniqueInfo.allClassic where LibraryCase.writtenCode[technique] != nil {
            var used: Set<String> = []
            for (key, state) in ordered where used.count < 6 {
                let parts = key.split(separator: "-")
                guard let puzzle = byPrefix[String(parts[0])], used.contains(puzzle.id) == false else { continue }
                let instances = Set((steps[key] ?? []).map { HoDoKu.interpret($0, in: state) }
                    .filter { $0.targets.contains(technique) }.map(\.moves))
                guard instances.count == 1, let expected = instances.first,
                      let hint = HintFinder.findHint(for: technique, in: state)
                else { continue }
                let moves = Set(hint.actions.compactMap(Move.init))
                guard moves.isEmpty == false, moves.isSubset(of: expected) else { continue }
                used.insert(puzzle.id)
                let index = Int(parts.last!)!
                lines.append("# \(technique.rawValue): \(puzzle.level) puzzle \(puzzle.id.prefix(24)), "
                    + (index % 2 == 0 ? "step \(index / 2 + 1)" : "step \(index / 2 + 1), thinned"))
                lines.append(LibraryCase.line(technique, digits: hint.reasoning.focusDigits, state: state,
                                              startingState: puzzle.startingState, expected: expected))
            }
        }
        let marker = "# Hand-made cases"
        let existing = (try? String(contentsOf: LibraryCase.ownURL, encoding: .utf8)) ?? ""
        let handMade = existing.range(of: marker).map { String(existing[$0.lowerBound...]) } ?? marker + "\n"
        let header = """
            # SudokuCore technique library, in HoDoKu's library format (see TechniqueLibraryTests.swift).
            # Codes are HoDoKu's, plus M100 Crane and M105 to M107 for 5- to 7-Y-Wings, which HoDoKu
            # doesn't have; a 4-Y-Wing is HoDoKu's WXYZ-Wing, 0802.
            #
            # Generated cases: corpus states where HoDoKu2 finds exactly one instance of the technique,
            # whose result each case records, and the hint finder's hint is part of it.
            # Rewrite them with SUDOKU_HODOKU_JAR=<jar> SUDOKU_UPDATE_TECHNIQUE_LIBRARY=1 swift test
            # -c release -Xswiftc -enable-testing --filter HoDoKuTests. Hand-made cases follow.

            """
        try (header + lines.joined(separator: "\n") + "\n\n" + handMade).write(to: LibraryCase.ownURL, atomically: true, encoding: .utf8)
    }

    @Test("HoDoKu finds exactly one solution to every corpus puzzle, the one recorded", .enabled(if: HoDoKu.isAvailable))
    func solutions() throws {
        let puzzles = CorpusPuzzle.all
        let solved = try HoDoKu.solutions(for: puzzles.map { ($0.id, $0.startingState) })
        for puzzle in puzzles {
            let result = solved[puzzle.id]
            #expect(result?.count == 1, "\(puzzle.testDescription): HoDoKu finds \(result?.count ?? -1) solutions")
            #expect(result?.solution == puzzle.solution, "\(puzzle.testDescription): HoDoKu's solution differs")
        }
    }
}
