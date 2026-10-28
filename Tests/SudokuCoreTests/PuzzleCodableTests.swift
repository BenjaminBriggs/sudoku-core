import Foundation
import Testing

@testable import SudokuCore

struct PuzzleCodableTests {

    init() {
        ConstraintRegistry.register(ForbidDigit.self)
    }

    @Test("Legacy puzzle JSON without new keys decodes as a classic puzzle")
    func legacyDecode() throws {
        // Shape matches what Puzzle has encoded to date: no constraints/presentation keys.
        let legacy = try JSONEncoder().encode(LegacyPuzzleShape.example)
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: legacy)
        #expect(puzzle.constraints.isEmpty)
        #expect(puzzle.presentation == nil)
        #expect(puzzle.solution == Puzzle.example().solution)
        #expect(puzzle.difficulty.hardestTechnique == TechniqueInfo.hiddenSingle.id)
    }

    @Test("A decoded puzzle keeps its authored id")
    func decodedIDKept() throws {
        var legacy = LegacyPuzzleShape.example
        legacy.id = "daily-2026-10-28"
        let puzzle = try JSONDecoder().decode(Puzzle.self, from: JSONEncoder().encode(legacy))
        #expect(puzzle.id == "daily-2026-10-28")
    }

    @Test("Puzzle id includes constraint identities, independent of order")
    func constrainedID() {
        let empty = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        let a = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 9))
        let b = AnyConstraint(ForbidDigit(position: .init(row: 4, column: 4), digit: 2))
        func puzzle(_ constraints: [AnyConstraint]) -> Puzzle {
            Puzzle(
                solution: Puzzle.example().solution, startingState: empty,
                difficulty: Puzzle.example().difficulty, constraints: constraints)
        }
        let givens = String(repeating: "0", count: 81)
        #expect(puzzle([]).id == givens)
        #expect(puzzle([a]).id == givens + "~forbid9-1")
        #expect(puzzle([a, b]).id == givens + "~forbid2-40_forbid9-1")
        #expect(puzzle([b, a]).id == puzzle([a, b]).id)
        #expect(puzzle([a]).id != puzzle([b]).id)
        // Classic ids are untouched, and presentation never takes part.
        #expect(Puzzle.example().id == Puzzle.example().startingState.flatString(empty: "0"))
        let presented = Puzzle(
            solution: Puzzle.example().solution, startingState: empty,
            difficulty: Puzzle.example().difficulty, constraints: [a],
            presentation: PuzzlePresentation(rulesText: "Only for show."))
        #expect(presented.id == puzzle([a]).id)
    }

    @Test("An explicit id is kept as given")
    func explicitID() {
        let puzzle = Puzzle(
            id: "bespoke-1", solution: Puzzle.example().solution,
            startingState: Puzzle.example().startingState, difficulty: Puzzle.example().difficulty,
            presentation: PuzzlePresentation(rulesText: "Rules core cannot encode."))
        #expect(puzzle.id == "bespoke-1")
    }

    @Test("Puzzle with constraints and presentation round-trips")
    func roundTrip() throws {
        let puzzle = Puzzle(
            solution: Puzzle.example().solution,
            startingState: Puzzle.example().startingState,
            difficulty: Puzzle.example().difficulty,
            constraints: [AnyConstraint(ForbidDigit(position: .init(row: 0, column: 1), digit: 9))],
            presentation: PuzzlePresentation(
                overlaySVG: "<svg/>",
                rulesText: "No 9 in r0c1."
            )
        )
        let data = try JSONEncoder().encode(puzzle)
        let decoded = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(decoded == puzzle)
        #expect(decoded.presentation?.rulesText == "No 9 in r0c1.")
        #expect(decoded.constraints.count == 1)
    }
}

/// Mirrors the on-disk shape of pre-constraint puzzles.
private struct LegacyPuzzleShape: Codable {
    var id: String
    let solution: [[Int]]
    let startingState: [[Int]]
    let difficulty: LegacyDifficulty

    struct LegacyDifficulty: Codable {
        let level: String
        let hardestTechnique: String
        let score: Int
    }

    static var example: LegacyPuzzleShape {
        let p = Puzzle.example()
        return LegacyPuzzleShape(
            id: p.id,
            solution: p.solution,
            startingState: p.startingState,
            difficulty: .init(level: "easy", hardestTechnique: "hiddenSingle", score: 0)
        )
    }
}
