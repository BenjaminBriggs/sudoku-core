//
//  BoardStateTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 02/10/2025.
//

import Testing
import SudokuCore

struct BoardStateTests {
    @Test("Decode sudoku.coach format")
    func testSudokuCoachDecoder() throws {
        // Test decoding a sudoku.coach format string
        let encoded = "SCv7_32_f2e9qjq91q1j037s9f720eaedg9att07fk0h44caggsd1pegl9vqu1sgf9nqp31shouptf6tnjauimivonqrisbjfmbfakn7favrjnghf4hacg1165ii6giphn3c8a88vemb2ouvgmk944s84jr42aah8vtmpc79ggm16jjkhlttpihmihihjhjllb9ngbqosgtmqsd96ncjcc2pko8iguoli403shj0cqg1s3r15skpuvfvgp040tjta5hid36l7tlskg215tpjp7bpok01posqcntvukbkjsnmvfaaig"
        
        let state = try BoardState(sudokuCoachString: encoded)
        
        // Verify basic structure
        #expect(state.grid.count == 9, "Grid should have 9 rows")
        #expect(state.grid[0].count == 9, "Grid should have 9 columns")
        #expect(state.pencilMarks.count == 9, "PencilMarks should have 9 rows")
        
        // Verify all grid values are valid (0-9)
        for row in 0..<9 {
            for col in 0..<9 {
                let value = state.grid[row][col]
                #expect(value >= 0 && value <= 9, "Grid value should be 0-9")
                
                // If cell has a value, pencilMarks should be empty
                if value > 0 {
                    #expect(state.pencilMarks[row][col].isEmpty, "Filled cell should have no pencil marks")
                } else {
                    // Empty cell should have pencil marks
                    #expect(state.pencilMarks[row][col].isEmpty == false, "Empty cell should have pencil marks")
                }
            }
        }
        
        // Verify we decoded something meaningful (not all empty)
        let filledCells = state.grid.flatMap { $0 }.filter { $0 > 0 }.count
        #expect(filledCells > 0, "Should have some filled cells")
    }
}
