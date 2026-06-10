import Foundation
import Testing

@testable import SudokuCore
@testable import SudokuKiller

struct KillerEndToEndTests {

    init() {
        KillerSudoku.register()
    }

    /// Builds a killer puzzle from the classic example: empties two adjacent cells
    /// and covers them with a cage derived from the known solution, so the puzzle
    /// is guaranteed consistent and killer-solvable.
    private func makeKillerPuzzle() -> Puzzle {
        let solution = Puzzle.example().solution
        var starting = solution
        starting[1][1] = 0  // solution 3
        starting[1][2] = 0  // solution 4
        let cage = KillerCage(
            cells: [.init(row: 1, column: 1), .init(row: 1, column: 2)],
            sum: solution[1][1] + solution[1][2]  // 7
        )
        return Puzzle(
            solution: solution,
            startingState: starting,
            difficulty: PuzzleDifficulty(
                level: .custom,
                hardestTechnique: TechniqueInfo.killerCageCombinations.id,
                score: 0
            ),
            constraints: [AnyConstraint(cage)],
            presentation: PuzzlePresentation(
                rulesText: "Cages sum to their totals; no repeats in a cage.")
        )
    }

    @Test("Killer puzzle round-trips through JSON after registration")
    func codableRoundTrip() throws {
        let puzzle = makeKillerPuzzle()
        let data = try JSONEncoder().encode(puzzle)
        let decoded = try JSONDecoder().decode(Puzzle.self, from: data)
        #expect(decoded == puzzle)
        #expect(decoded.constraints.first?.base is KillerCage)
        #expect(decoded.presentation?.rulesText == puzzle.presentation?.rulesText)
    }

    @Test("Killer puzzle solves with combined classic + killer techniques")
    func endToEndSolve() {
        let puzzle = makeKillerPuzzle()
        var state = BoardState.fromGrid(puzzle.startingState, constraints: puzzle.constraints)
        let techniques = ClassicTechniques.all + KillerSudoku.techniques
        var iterations = 0

        while state.isSolved == false && iterations < 200 {
            iterations += 1
            guard let hint = HintFinder.firstHint(in: state, using: techniques) else { break }
            state = state.applying(hint)
        }

        #expect(state.isSolved)
        #expect(state.grid == puzzle.solution)
    }

    @Test("Killer techniques fire where classic techniques cannot")
    func killerTechniquesNeeded() throws {
        // Empty grid except a single 2-cell cage: classic techniques see 9 candidates
        // everywhere and find nothing; CageCombinations must act on pencil marks.
        let cage = KillerCage(
            cells: [.init(row: 4, column: 4), .init(row: 4, column: 5)],
            sum: 3
        )
        var state = BoardState.fromGrid(
            Array(repeating: Array(repeating: 0, count: 9), count: 9))
        state.constraints = [AnyConstraint(cage)]
        let hint = try #require(
            HintFinder.firstHint(in: state, using: KillerSudoku.techniques))
        #expect(hint.technique.id == TechniqueInfo.killerCageCombinations.id)
    }

    @Test("Board play with a killer puzzle prunes and validates")
    @MainActor
    func boardPlay() {
        // Sparse board: classic rules allow all nine digits at (4,4); only the cage
        // narrows the candidates, proving Board applies constraint pruning.
        let cage = KillerCage(
            cells: [.init(row: 4, column: 4), .init(row: 4, column: 5)],
            sum: 3
        )
        let board = Board(
            givenCells: Array(repeating: Array(repeating: 0, count: 9), count: 9),
            constraints: [AnyConstraint(cage)]
        )
        #expect(board.cell(at: .init(row: 4, column: 4)).validOptions == Set([1, 2]))
        #expect(board.cell(at: .init(row: 4, column: 5)).validOptions == Set([1, 2]))
        #expect(board.constraintViolations.isEmpty)

        // Breaking the cage sum surfaces a violation.
        board.mark(positions: [.init(row: 4, column: 4)], as: 5)
        #expect(board.constraintViolations.isEmpty == false)
    }
}
