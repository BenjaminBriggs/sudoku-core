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
    let id: String
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
