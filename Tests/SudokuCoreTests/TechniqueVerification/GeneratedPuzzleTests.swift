//
//  GeneratedPuzzleTests.swift
//  SudokuCore
//
//  Fresh puzzles as a source of edge cases. In the soak, SUDOKU_SOAK_GENERATE=N makes N puzzles
//  per level and symmetry with the steered generator, plus N blind minimal puzzles per symmetry
//  that no rating has filtered. Each joins the corpus, so every state of its solve gets the full
//  verification, and with HoDoKu installed, HoDoKuTests checks its solution and every state.
//
import Foundation
import Synchronization
import Testing
@testable import SudokuCore

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
                let grid = minimalPuzzle(from: solution, symmetry: symmetry)
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

    /// `solution` with clues removed an orbit at a time, in random order, while it keeps one
    /// solution: a minimal puzzle no rating has filtered.
    static func minimalPuzzle(from solution: [[Int]], symmetry: Symmetry) -> [[Int]] {
        var grid = solution
        for orbit in symmetry.orbits.shuffled() {
            let saved = orbit.map { grid[$0.row][$0.column] }
            for cell in orbit { grid[cell.row][cell.column] = 0 }
            if Validator.solutionCount(of: grid).isUnique == false {
                for (cell, value) in zip(orbit, saved) { grid[cell.row][cell.column] = value }
            }
        }
        return grid
    }
}

struct GeneratedPuzzleTests {
    @Test("The hint finder's solve reaches the generator's solution and matches the reference finders' solve",
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

        // A second logical solve, from the definitions: apply everything every reference finder
        // licenses, over and over, until nothing changes.
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
