//
//  GeneratedPuzzleTests.swift
//  SudokuCore
//
//  Fresh puzzles as a source of edge cases. In the soak, SUDOKU_SOAK_GENERATE=N makes N puzzles
//  per level and symmetry with the steered generator, plus N blind minimal puzzles per symmetry
//  that no rating has filtered. Each goes through an independent brute-force solver and an
//  independent logical solve built from the reference finders, and joins the corpus so every
//  state of its solve gets the full verification.
//
import Foundation
import Synchronization
import Testing
@testable import SudokuCore

/// A plain backtracking solver, sharing no code with core's solvers.
enum BruteForce {
    /// Up to `limit` solutions of `grid`.
    static func solutions(of grid: [[Int]], limit: Int = 2) -> [[[Int]]] {
        var cells = grid.flatMap { $0 }
        var rows = Array(repeating: 0, count: 9), columns = rows, boxes = rows
        for index in 0..<81 where cells[index] != 0 {
            let bit = 1 << cells[index], r = index / 9, c = index % 9, b = (r / 3) * 3 + c / 3
            if rows[r] & bit != 0 || columns[c] & bit != 0 || boxes[b] & bit != 0 { return [] }
            rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
        }
        var found: [[[Int]]] = []

        func search() {
            // The empty cell with the fewest options, so dead ends show early.
            var best = -1, bestOptions = 0, bestCount = 10
            for index in 0..<81 where cells[index] == 0 {
                let r = index / 9, c = index % 9, b = (r / 3) * 3 + c / 3
                let options = ~(rows[r] | columns[c] | boxes[b]) & 0b11_1111_1110
                let count = options.nonzeroBitCount
                if count < bestCount { best = index; bestOptions = options; bestCount = count }
                if count == 0 { return }
            }
            guard best >= 0 else {
                found.append((0..<9).map { r in Array(cells[(r * 9)..<(r * 9 + 9)]) })
                return
            }
            let r = best / 9, c = best % 9, b = (r / 3) * 3 + c / 3
            for digit in 1...9 where bestOptions & (1 << digit) != 0 {
                let bit = 1 << digit
                cells[best] = digit; rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
                search()
                cells[best] = 0; rows[r] &= ~bit; columns[c] &= ~bit; boxes[b] &= ~bit
                if found.count >= limit { return }
            }
        }
        search()
        return found
    }

    /// `solution` with clues removed an orbit at a time, in random order, while it keeps one
    /// solution: a minimal puzzle no rating has filtered.
    static func minimalPuzzle(from solution: [[Int]], symmetry: Symmetry) -> [[Int]] {
        var grid = solution
        for orbit in symmetry.orbits.shuffled() {
            let saved = orbit.map { grid[$0.row][$0.column] }
            for cell in orbit { grid[cell.row][cell.column] = 0 }
            if solutions(of: grid).count != 1 {
                for (cell, value) in zip(orbit, saved) { grid[cell.row][cell.column] = value }
            }
        }
        return grid
    }
}

/// Puzzles made fresh for the soak, tagged with how they were made.
enum GeneratedCorpus {
    static let perCase = Int(ProcessInfo.processInfo.environment["SUDOKU_SOAK_GENERATE"] ?? "") ?? 0

    static let puzzles: [CorpusPuzzle] = {
        guard CorpusPuzzle.isSoak, perCase > 0 else { return [] }
        let levels: [PuzzleDifficulty.Level] = [.easy, .medium, .hard, .expert, .professional]
        let symmetries: [Symmetry] = [.none, .rotational180, .diagonal]
        enum Kind { case steered(PuzzleDifficulty.Level, Symmetry), blind(Symmetry) }
        let kinds = levels.flatMap { level in symmetries.map { Kind.steered(level, $0) } } + symmetries.map { Kind.blind($0) }
        let jobs = kinds.flatMap { kind in Array(repeating: kind, count: perCase) }

        let made = Mutex<[CorpusPuzzle]>([])
        DispatchQueue.concurrentPerform(iterations: jobs.count) { index in
            let puzzle: CorpusPuzzle?
            switch jobs[index] {
            case .steered(let level, let symmetry):
                // Best effort: a puzzle that missed its level is as good a test as one that hit it.
                puzzle = SudokuGenerator.createPuzzle(level: level, symmetry: symmetry, bestEffort: true).map {
                    CorpusPuzzle(id: Self.id(of: $0.puzzle.startingState),
                                 level: "steered \(level.rawValue)→\($0.result.level.rawValue) \(symmetry.rawValue)",
                                 startingState: $0.puzzle.startingState, solution: $0.puzzle.solution)
                }
            case .blind(let symmetry):
                let solution = SolutionGenerator.generateRandomSolution()
                let grid = BruteForce.minimalPuzzle(from: solution, symmetry: symmetry)
                puzzle = CorpusPuzzle(id: Self.id(of: grid), level: "blind \(symmetry.rawValue)", startingState: grid, solution: solution)
            }
            if let puzzle { made.withLock { $0.append(puzzle) } }
        }
        let sorted = made.withLock { $0 }.sorted { $0.id < $1.id }
        if let path = ProcessInfo.processInfo.environment["SUDOKU_SOAK_GENERATED_OUT"],
           let data = try? JSONEncoder().encode(sorted) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        return sorted
    }()

    static func id(of grid: [[Int]]) -> String { grid.flatMap { $0 }.map(String.init).joined() }
}

struct GeneratedPuzzleTests {
    @Test("A generated puzzle has exactly one solution, the one the generator gave",
          .enabled(if: GeneratedCorpus.puzzles.isEmpty == false), arguments: GeneratedCorpus.puzzles)
    func solutionMatchesBruteForce(_ puzzle: CorpusPuzzle) {
        let solutions = BruteForce.solutions(of: puzzle.startingState)
        #expect(solutions.count == 1, "\(solutions.count) solutions")
        #expect(solutions.first == puzzle.solution, "the brute-force solution differs from the generator's")
        #expect(Validator.solutionCount(of: puzzle.startingState).isUnique, "core's uniqueness check disagrees")
    }

    @Test("The hint finder's solve matches the brute-force solution and the reference finders' solve",
          .enabled(if: GeneratedCorpus.puzzles.isEmpty == false), arguments: GeneratedCorpus.puzzles)
    func solveMatchesReference(_ puzzle: CorpusPuzzle) throws {
        let path = SolvePathEmitter.emit(from: puzzle.startingState)
        if path.solved {
            #expect(path.finalState.grid == puzzle.solution, "the hint finder solved it to a different grid")
        }
        if puzzle.level.hasPrefix("steered") {
            #expect(path.solved, "the generator accepted a puzzle the hint finder can't solve")
            #expect(try SudokuDifficultyCalculator.calculateDifficulty(for: puzzle.startingState).needsGuessing == false)
        }

        // An independent logical solve: apply everything every reference finder licenses, over
        // and over, until nothing changes.
        var state = BoardState.fromGrid(puzzle.startingState, assumingUniqueSolution: true)
        var problems: [String] = []
        while true {
            var actions: [HintAction] = []
            for (technique, licensed) in Reference.licensedAll(TechniqueVerificationTests.techniques, in: state) {
                for c in licensed.placements {
                    if puzzle.solution[c.row][c.column] != c.digit { problems.append("\(technique.rawValue) places \(c) wrongly") }
                    actions.append(HintAction(position: Puzzle.Index(row: c.row, column: c.column), solveAs: c.digit))
                }
                for c in licensed.eliminations {
                    if puzzle.solution[c.row][c.column] == c.digit { problems.append("\(technique.rawValue) removes answer \(c)") }
                    actions.append(HintAction(position: Puzzle.Index(row: c.row, column: c.column), ruleOut: c.digit))
                }
            }
            guard actions.isEmpty == false, problems.isEmpty else { break }
            state = state.applying(HintStep(actions: actions, technique: .unknown))
        }

        #expect(problems.isEmpty, "\(problems.prefix(4))")
        let referenceSolved = state.isSolved && state.grid == puzzle.solution
        if referenceSolved != path.solved {
            SoakFailures.record(puzzle, ["hint finder solved \(path.solved), reference finders solved \(referenceSolved)"])
        }
        #expect(referenceSolved == path.solved,
                "hint finder solved: \(path.solved) after \(path.steps.count) steps; reference finders solved: \(referenceSolved)")
    }
}
