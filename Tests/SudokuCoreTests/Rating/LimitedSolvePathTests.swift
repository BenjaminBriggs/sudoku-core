import Testing
@testable import SudokuCore

@Suite("Solve paths with a chosen set of techniques")
struct LimitedSolvePathTests {
    /// Solved by singles and Pointing.
    private let needsPointing: [[Int]] = Solution.cells(
        from: "020608000580009700000040000370000500600000004008000013000020000009800036000306090"
    )

    @Test("Techniques up to a level stop at that level")
    func upToKeepsTheLevel() {
        let easy = ClassicTechniques.upTo(.easy)
        #expect(easy.allSatisfy { $0.info.level <= .easy })
        #expect(easy.contains { $0.info == .hiddenSingle })
        #expect(easy.contains { $0.info == .lockedCandidatesPointing } == false)
        #expect(ClassicTechniques.upTo(.professional).count == ClassicTechniques.all.count)
    }

    @Test("A solver short of a technique stalls where it's needed")
    func stallsWithoutTheTechnique() {
        #expect(SolvePathEmitter.emit(from: needsPointing).solved)
        let singlesOnly = SolvePathEmitter.emit(from: needsPointing, using: ClassicTechniques.upTo(.easy))
        #expect(singlesOnly.solved == false)
        #expect(singlesOnly.steps.allSatisfy { $0.technique.isSingle })
        #expect(SolvePathEmitter.emit(from: needsPointing, using: ClassicTechniques.upTo(.medium)).solved)
    }

    @Test("Carrying on from a state reaches the same grid as solving from the clues")
    func continuingMatchesFromGrid() {
        let techniques = ClassicTechniques.upTo(.hard)
        let fromGrid = SolvePathEmitter.emit(from: needsPointing, using: techniques)
        let continued = SolvePathEmitter.emit(continuingFrom: BoardState.fromGrid(needsPointing), using: techniques)
        #expect(continued.solved)
        #expect(continued.finalState.grid == fromGrid.finalState.grid)
    }

    @Test("A state that doesn't assume uniqueness never gets the uniqueness techniques")
    func continuingKeepsTheUniquenessSetting() {
        let path = SolvePathEmitter.emit(continuingFrom: BoardState.fromGrid(needsPointing), using: ClassicTechniques.all)
        let uniqueness: Set<TechniqueInfo> = [
            .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType3,
            .uniqueRectangleType4, .uniqueRectangleType5, .bug,
        ]
        #expect(path.steps.contains { uniqueness.contains($0.technique) } == false)
    }
}
