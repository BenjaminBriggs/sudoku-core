import Testing
@testable import SudokuCore

struct SudokuGeneratorTests {
    private let solvedGrid: [[Int]] = [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9]
    ]
    
    @Test("Generator keeps valid removals when uniqueness temporarily fails")
    func testBatchUniquenessKeepsValidRemovals() async {
        let batchOrder: [Puzzle.Index] = [
            Puzzle.Index(row: 0, column: 1),
            Puzzle.Index(row: 1, column: 0),
            Puzzle.Index(row: 1, column: 1),
            Puzzle.Index(row: 2, column: 2),
            Puzzle.Index(row: 0, column: 0)
        ]
        
        let failingIndex = batchOrder.last!
        let uniquenessCheck: ([[Int]]) -> Bool = { puzzle in
            puzzle[failingIndex.row][failingIndex.column] != 0
        }
        
        let puzzle = await SudokuGenerator.createPuzzle(
            from: solvedGrid,
            targetEmpty: 4,
            cellsOrder: batchOrder,
            uniqueCheck: uniquenessCheck
        )
        
        let zeroCount = puzzle.flatMap { $0 }.filter { $0 == 0 }.count
        #expect(zeroCount == 4)
        
        for position in batchOrder.dropLast() {
            #expect(puzzle[position.row][position.column] == 0)
        }
        
        #expect(puzzle[failingIndex.row][failingIndex.column] == solvedGrid[failingIndex.row][failingIndex.column])
    }
    
    @Test("Generator does not exceed target empty count")
    func testRespectsTargetEmptyWithBatchCommit() async {
        let order: [Puzzle.Index] = (0..<81).map { offset in
            Puzzle.Index(row: offset / 9, column: offset % 9)
        }
        let alwaysUnique: ([[Int]]) -> Bool = { _ in true }
        let targetEmpty = 7
        
        let puzzle = await SudokuGenerator.createPuzzle(
            from: solvedGrid,
            targetEmpty: targetEmpty,
            cellsOrder: order,
            uniqueCheck: alwaysUnique
        )
        
        let zeroCount = puzzle.flatMap { $0 }.filter { $0 == 0 }.count
        #expect(zeroCount == targetEmpty)
        
        for (offset, index) in order.enumerated() {
            if offset < targetEmpty {
                #expect(puzzle[index.row][index.column] == 0)
            } else {
                #expect(puzzle[index.row][index.column] == solvedGrid[index.row][index.column])
            }
        }
    }
}
