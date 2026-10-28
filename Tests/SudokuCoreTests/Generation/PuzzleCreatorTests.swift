import Testing
@testable import SudokuCore

struct PuzzleCreatorTests {

    @Test("createPuzzleWithDifficulty stops when its task is cancelled")
    func testGenerationHonoursCancellation() async {
        let task = Task {
            try await PuzzleCreator.createPuzzleWithDifficulty(.hard)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
