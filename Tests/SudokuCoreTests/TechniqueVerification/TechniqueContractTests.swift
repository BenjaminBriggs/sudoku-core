//
//  TechniqueContractTests.swift
//  SudokuCore
//
//  The promises the generator relies on: technique names stay decodable, the uniqueness
//  techniques only run on puzzles with one solution, ratings only move on purpose, and every
//  puzzle the generator accepts is solvable by the hint finder.
//
import Foundation
import Testing
@testable import SudokuCore

struct TechniqueNameTests {
    @Test("Every technique round-trips through its name")
    func roundTrip() throws {
        let ids = TechniqueInfo.allClassic.map(\.id)
        for id in ids {
            #expect(TechniqueID(rawValue: id.rawValue) == id)
        }
        let data = try JSONEncoder().encode(ids)
        #expect(try JSONDecoder().decode([TechniqueID].self, from: data) == ids)
        #expect(try JSONDecoder().decode([TechniqueInfo].self, from: JSONEncoder().encode(TechniqueInfo.allClassic))
            == TechniqueInfo.allClassic)
    }

    @Test("The retired Y-Wing name decodes as XY-Wing")
    func legacyYWing() throws {
        #expect(TechniqueID(rawValue: "yWing") == TechniqueInfo.xyWing.id)
        let decoded = try JSONDecoder().decode([TechniqueID].self, from: Data(#"["yWing","xyWing"]"#.utf8))
        #expect(decoded == [TechniqueInfo.xyWing.id, TechniqueInfo.xyWing.id])
        #expect(ClassicTechniques.technique(for: "yWing")?.info == .xyWing)
        #expect(ClassicTechniques.technique(for: "notATechnique") == nil)
    }

    @Test("A puzzle saved with the retired Y-Wing name reads as XY-Wing")
    func legacyYWingPuzzle() throws {
        let difficulty = PuzzleDifficulty(level: .hard, hardestTechnique: TechniqueInfo.xyWing.id, score: 700)
        let json = String(decoding: try JSONEncoder().encode(difficulty), as: UTF8.self)
            .replacingOccurrences(of: #""xyWing""#, with: #""yWing""#)
        #expect(json.contains(#""yWing""#))
        let decoded = try JSONDecoder().decode(PuzzleDifficulty.self, from: Data(json.utf8))
        #expect(decoded.hardestTechnique == TechniqueInfo.xyWing.id)
    }

    @Test("The classic set is in solve order and matches the classic infos")
    func classicOrder() {
        let infos = ClassicTechniques.all.map(\.info)
        #expect(infos == TechniqueInfo.allClassic.filter { $0 != .unknown })
        #expect(zip(infos, infos.dropFirst()).allSatisfy { $0.difficulty <= $1.difficulty })
    }
}

@MainActor
struct UniquenessOptInTests {
    static let unique = CorpusPuzzle.fixtureCorpus[0]

    @Test("Board states only assume one solution when the givens have one")
    func boardKnowsUniqueness() {
        let board = Board(givenCells: Self.unique.startingState, solution: Self.unique.solution)
        #expect(board.hasUniqueSolution)
        #expect(board.state.assumesUniqueSolution)

        let empty = Board()
        #expect(empty.hasUniqueSolution == false)
        #expect(empty.state.assumesUniqueSolution == false)
    }

    @Test("A plain grid doesn't assume one solution, and applying hints keeps the flag")
    func flagIsExplicitAndKept() throws {
        #expect(BoardState.fromGrid(Self.unique.startingState).assumesUniqueSolution == false)
        let state = BoardState.fromGrid(Self.unique.startingState, assumingUniqueSolution: true)
        let hint = try #require(HintFinder.firstHint(in: state))
        #expect(state.applying(hint).assumesUniqueSolution)
    }

    @Test("Rating checks uniqueness itself, so a grid with many solutions never uses it")
    func ratingChecksUniqueness() {
        #expect(SolvePathEmitter.emit(from: Self.unique.startingState).finalState.assumesUniqueSolution)
        #expect(SolvePathEmitter.emit(from: Solution.empty()).finalState.assumesUniqueSolution == false)
    }
}

/// A puzzle's rating at the time the snapshot was taken.
struct RatingSnapshot: Codable, Equatable, Sendable, CustomTestStringConvertible {
    let id: String
    let level: String
    let score: Double
    let seRating: Double?
    let hodokuRating: Int?
    let hardestTechnique: String?
    let needsGuessing: Bool

    var testDescription: String { "\(level) \(id.prefix(18))…" }

    init(id: String, _ result: SudokuDifficultyCalculator.DifficultyResult) {
        self.id = id
        level = result.level.rawValue
        score = result.score
        seRating = result.seRating
        hodokuRating = result.hodokuRating
        hardestTechnique = result.hardestTechnique?.rawValue
        needsGuessing = result.needsGuessing
    }

    static let url = Bundle.module.url(forResource: "rating-snapshots", withExtension: "json", subdirectory: "Fixtures")
    static let all: [RatingSnapshot] = url.flatMap { try? JSONDecoder().decode([RatingSnapshot].self, from: Data(contentsOf: $0)) } ?? []

    /// Where the snapshot lives in the source tree, for `SUDOKU_UPDATE_SNAPSHOTS=1`.
    static let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/rating-snapshots.json")
}

struct RatingSnapshotTests {
    static let isUpdating = ProcessInfo.processInfo.environment["SUDOKU_UPDATE_SNAPSHOTS"] != nil

    @Test("Ratings match their snapshot; a finder change that moves one must update it on purpose",
          .enabled(if: isUpdating == false), arguments: RatingSnapshot.all)
    func matchesSnapshot(_ snapshot: RatingSnapshot) throws {
        let puzzle = try #require(CorpusPuzzle.fixtureCorpus.first { $0.id == snapshot.id })
        let rating = RatingSnapshot(id: puzzle.id, try SudokuDifficultyCalculator.calculateDifficulty(for: puzzle.startingState))
        #expect(rating == snapshot, "rerun with SUDOKU_UPDATE_SNAPSHOTS=1 if this change is intended")
    }

    @Test("Snapshot file covers the corpus", .enabled(if: isUpdating == false))
    func coversCorpus() {
        #expect(RatingSnapshot.all.count == CorpusPuzzle.fixtureCorpus.count)
    }

    @Test("Rewrite the rating snapshot", .enabled(if: isUpdating))
    func update() throws {
        let snapshots = try CorpusPuzzle.fixtureCorpus.map {
            RatingSnapshot(id: $0.id, try SudokuDifficultyCalculator.calculateDifficulty(for: $0.startingState))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshots).write(to: RatingSnapshot.sourceURL)
    }
}

struct GeneratorContractTests {
    /// Per commit: the quick levels, with and without symmetry. The soak adds the hard levels.
    static let cases: [(PuzzleDifficulty.Level, Symmetry)] = {
        let levels: [PuzzleDifficulty.Level] = CorpusPuzzle.isSoak ? [.easy, .medium, .hard, .expert, .professional] : [.easy, .medium, .hard]
        let symmetries: [Symmetry] = CorpusPuzzle.isSoak ? [.none, .rotational180, .rotational90, .diagonal] : [.none, .rotational180]
        return levels.flatMap { level in symmetries.map { (level, $0) } }
    }()

    @Test("Every puzzle the generator accepts is unique and solved by the hint finder", arguments: cases)
    func acceptedPuzzlesAreSolvable(_ level: PuzzleDifficulty.Level, _ symmetry: Symmetry) throws {
        guard let steered = SudokuGenerator.createPuzzle(level: level, symmetry: symmetry, bestEffort: true) else { return }
        let grid = steered.puzzle.startingState
        #expect(Validator.solutionCount(of: grid).isUnique)
        let rating = try SudokuDifficultyCalculator.calculateDifficulty(for: grid)
        #expect(rating.needsGuessing == false)
        let path = SolvePathEmitter.emit(from: grid)
        #expect(path.solved)
        #expect(path.finalState.grid == steered.puzzle.solution)
    }
}
