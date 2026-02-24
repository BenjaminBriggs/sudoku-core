//
//  BoardStateTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 02/10/2025.
//

import Testing
@testable import SudokuCore

struct BoardStateTests {
    @Test("Decode sudoku.coach format - structural validity")
    func testSudokuCoachDecoder() throws {
        let encoded = "SCv7_32_f2e9qjq91q1j037s9f720eaedg9att07fk0h44caggsd1pegl9vqu1sgf9nqp31shouptf6tnjauimivonqrisbjfmbfakn7favrjnghf4hacg1165ii6giphn3c8a88vemb2ouvgmk944s84jr42aah8vtmpc79ggm16jjkhlttpihmihihjhjllb9ngbqosgtmqsd96ncjcc2pko8iguoli403shj0cqg1s3r15skpuvfvgp040tjta5hid36l7tlskg215tpjp7bpok01posqcntvukbkjsnmvfaaig"

        let state = try BoardStateParser.parseSudokuCoach(encoded)

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
                }
            }
        }

        // Verify we decoded something meaningful (not all empty)
        let filledCells = state.grid.flatMap { $0 }.filter { $0 > 0 }.count
        #expect(filledCells > 0, "Should have some filled cells")
    }

    @Test("Decode sudoku.coach format - known cell values and pencil marks")
    func testSudokuCoachDecoderKnownValues() throws {
        // Base puzzle: 900235410201964053543718000050403000310650004490821030805142300139580042024300080
        let encoded = "SCv7_32_f2e5aju11m1j036s4lnp076r1475vei14t024gkh207q0vdktbn7b820h4alne9rveebfqd7qjet6asq78aacjuf73f557smr7a2c01076r80o43ctofl86a1bk73g20bb4o4tqqj41ggmm50ie6al6ea9oakp84sgm1ac45f7672qn260qerm55lpem4dk2i9ckk6tggghkhu68vv43bl30neavvtd3pus6taqp91b5cq7bris8rlefd7eif7muo5ji3sg5ph8g3bvn8gpbuqqedkf9tlqp7m4srpobpmkkoio"

        let state = try BoardStateParser.parseSudokuCoach(encoded)

        // Cell (0,0) should be solved as 9 (given digit)
        #expect(state.grid[0][0] == 9, "Cell (0,0) should be 9")
        #expect(state.pencilMarks[0][0].isEmpty, "Solved cell (0,0) should have no pencil marks")

        // Cell (0,1) should have pencil marks {6, 7, 8}
        #expect(state.grid[0][1] == 0, "Cell (0,1) should be unsolved")
        #expect(state.pencilMarks[0][1] == Set([6, 7, 8]), "Cell (0,1) should have pencil marks {6, 7, 8}")

        // Verify all given digits from base puzzle are present
        let basePuzzle = "900235410201964053543718000050403000310650004490821030805142300139580042024300080"
        for (i, ch) in basePuzzle.enumerated() {
            let digit = Int(String(ch))!
            if digit > 0 {
                #expect(
                    state.grid[i / 9][i % 9] == digit,
                    "Given digit at (\(i / 9),\(i % 9)) should be \(digit)"
                )
            }
        }
    }

    @Test("Decode sudoku.coach format - second puzzle grid verification")
    func testSudokuCoachDecoderSecondPuzzle() throws {
        let encoded = "SCv7_32_f2e7qjmh1b13037sisvav45496deslfvo0nhhb4cobc86jgv2jvtq5g75b4bg462snn951srppijp5brepuuln2kdpsjj5l9lgbteeu6814j96m4cim01a3404hkm8m1l1m2i14ec84g0b19a800c300m4910l90mgghja303leefbknfgve8u9u1j5lhhj1pnmh1u1t42qtllvsgdtaqpdvb7tejo09nh816k15gj6ofih0t8jftml1f496n1mdmv2v3upt6rrno0cjs13j4"

        let state = try BoardStateParser.parseSudokuCoach(encoded)

        let expectedGrid = "413295678579846001628317459251764893347589000896123040130070000765030000980651000"

        for (i, ch) in expectedGrid.enumerated() {
            let digit = Int(String(ch))!
            let row = i / 9
            let col = i % 9
            #expect(
                state.grid[row][col] == digit,
                "Cell (\(row),\(col)) should be \(digit), got \(state.grid[row][col])"
            )
        }

        // Verify filled cell count matches
        let expectedFilled = expectedGrid.filter { $0 != "0" }.count
        let actualFilled = state.grid.flatMap { $0 }.filter { $0 > 0 }.count
        #expect(actualFilled == expectedFilled, "Filled cell count should match")

        // Verify known pencil marks
        #expect(
            state.validOptions[1][6] == Set([2, 3]),
            "Cell (0,6) should have pencil marks {2, 3}"
        )
        #expect(
            state.validOptions[1][7] == Set([2, 3]),
            "Cell (0,7) should have pencil marks {2, 3}"
        )
        
        
        #expect(
            state.validOptions[6][2] == Set([2, 4]),
            "Cell (6,2) should have pencil marks {2, 4}"
        )
        
        #expect(
            state.validOptions[6][3] == Set([4, 9]),
            "Cell (6,2) should have pencil marks {4, 9}"
        )
    }
    
    @Test("Decode sudoku.coach format - second puzzle grid verification")
    func testSudokuCoachDecoderThridPuzzle() throws {
        let encoded = "SCv7_32_f2e6aji1hr1j027shf7ka0kc67nbbus3nqg55b68aba47mutoenflts5kguk81brm23m3r5v6jfsct0unsuhrmp1pnhqentvoou1ttrk9i21s9805ep7iobch0d494sd5p65ashjunphll686h5uakhjotqcg2qrpnad48btrvturl4nslqbijj3n8u7kf44i2pk4p98bpa1173ghidq100p20og8o8g9kh838g65igs8g2mk2u0t8jqpvjgocjfe9r06tb3e0vhvpklrjjidt8vgir59dp0rse4t7v2esb945ri1n9k1gqond6cuvs9pl6c0"
        
        let state = try BoardStateParser.parseSudokuCoach(encoded)
        
        let expectedGrid = "100005000007028000209006000094000070521743986070000001918634725732050060005287319"
        
        for (i, ch) in expectedGrid.enumerated() {
            let digit = Int(String(ch))!
            let row = i / 9
            let col = i % 9
            #expect(
                state.grid[row][col] == digit,
                "Cell (\(row),\(col)) should be \(digit), got \(state.grid[row][col])"
            )
        }
        
        // Verify filled cell count matches
        let expectedFilled = expectedGrid.filter { $0 != "0" }.count
        let actualFilled = state.grid.flatMap { $0 }.filter { $0 > 0 }.count
        #expect(actualFilled == expectedFilled, "Filled cell count should match")
        
        // Verify known pencil marks
        #expect(
            state.pencilMarks[3][3] == Set([5, 8]),
            "Cell (3,3) should have pencil marks {2, 3}"
        )
    }
    // MARK: - Format Detection Tests

    @Test("detectFormat identifies sudoku.coach strings")
    func testDetectFormatSudokuCoach() {
        let format = BoardStateParser.detectFormat("SCv7_32_abc123")
        #expect(format == .sudokuCoach)
    }

    @Test("detectFormat identifies 81-digit grid strings")
    func testDetectFormatGridString() {
        let gridString = "000000000000000000000000000000000000000000283000000154000000000000000070000000090"
        let format = BoardStateParser.detectFormat(gridString)
        #expect(format == .gridString81)
    }

    @Test("detectFormat returns nil for unrecognised input")
    func testDetectFormatUnrecognised() {
        #expect(BoardStateParser.detectFormat("") == nil)
        #expect(BoardStateParser.detectFormat("too short") == nil)
        #expect(BoardStateParser.detectFormat("not a valid format at all and definitely not 81 digits") == nil)
        // 81 characters but not all digits
        #expect(BoardStateParser.detectFormat("abcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghi") == nil)
    }

    // MARK: - Grid String Parsing Tests

    @Test("parseGridString produces correct BoardState")
    func testParseGridString() throws {
        let gridString = "000000000000000000000000000000000000000000283000000154000000000000000070000000090"

        let state = try BoardStateParser.parseGridString(gridString)

        // Check known cell values
        #expect(state.grid[4][6] == 2)
        #expect(state.grid[4][7] == 8)
        #expect(state.grid[4][8] == 3)
        #expect(state.grid[5][6] == 1)
        #expect(state.grid[5][7] == 5)
        #expect(state.grid[5][8] == 4)

        // Empty cells should have pencil marks computed
        #expect(state.pencilMarks[0][0].isEmpty == false, "Empty cell should have pencil marks")
    }

    @Test("parseGridString rejects invalid input")
    func testParseGridStringInvalid() {
        #expect(throws: BoardStateParseError.invalidGridString) {
            try BoardStateParser.parseGridString("123")
        }
        #expect(throws: BoardStateParseError.invalidGridString) {
            try BoardStateParser.parseGridString("abcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghi")
        }
    }

    // MARK: - Auto-Detect Parse Tests

    @Test("parse auto-detects grid string format")
    func testParseAutoDetectsGridString() throws {
        let gridString = "000000000000000000000000000000000000000000283000000154000000000000000070000000090"

        let state = try BoardStateParser.parse(gridString)
        #expect(state.grid[4][6] == 2)
    }

    @Test("parse auto-detects sudoku.coach format")
    func testParseAutoDetectsSudokuCoach() throws {
        let encoded = "SCv7_32_f2e7qjmh1b13037sisvav45496deslfvo0nhhb4cobc86jgv2jvtq5g75b4bg462snn951srppijp5brepuuln2kdpsjj5l9lgbteeu6814j96m4cim01a3404hkm8m1l1m2i14ec84g0b19a800c300m4910l90mgghja303leefbknfgve8u9u1j5lhhj1pnmh1u1t42qtllvsgdtaqpdvb7tejo09nh816k15gj6ofih0t8jftml1f496n1mdmv2v3upt6rrno0cjs13j4"

        let state = try BoardStateParser.parse(encoded)
        #expect(state.grid[0][0] == 4)
        #expect(state.grid[0][1] == 1)
        #expect(state.grid[0][2] == 3)
    }

    @Test("parse throws for unrecognised format")
    func testParseThrowsForUnrecognised() {
        #expect(throws: BoardStateParseError.unrecognizedFormat) {
            try BoardStateParser.parse("not a valid format")
        }
    }

    // MARK: - Error Case Tests

    @Test("parseSudokuCoach rejects strings without SCv7_32_ prefix")
    func testSudokuCoachRejectsInvalidPrefix() {
        #expect(throws: BoardStateParseError.unrecognizedFormat) {
            try BoardStateParser.parseSudokuCoach("INVALID_PREFIX_abc123")
        }
    }

    // MARK: - validOptions Independence Tests

    @Test("validOptions are computed from grid, not copied from pencil marks")
    func testValidOptionsComputedFromGrid() throws {
        let encoded = "SCv7_32_f2e7qjmh1b13037sisvav45496deslfvo0nhhb4cobc86jgv2jvtq5g75b4bg462snn951srppijp5brepuuln2kdpsjj5l9lgbteeu6814j96m4cim01a3404hkm8m1l1m2i14ec84g0b19a800c300m4910l90mgghja303leefbknfgve8u9u1j5lhhj1pnmh1u1t42qtllvsgdtaqpdvb7tejo09nh816k15gj6ofih0t8jftml1f496n1mdmv2v3upt6rrno0cjs13j4"

        let state = try BoardStateParser.parseSudokuCoach(encoded)

        // validOptions should match what Validator computes from the grid
        let expectedValidOptions = Validator.validOptions(for: state.grid)
        #expect(state.validOptions == expectedValidOptions, "validOptions should be computed from the grid via Validator")

        // pencilMarks and validOptions may differ (user may not have marked all candidates)
        // This is the key distinction — validOptions should be complete even if pencilMarks are sparse
        var pencilMarkTotal = 0
        var validOptionsTotal = 0
        for row in 0..<9 {
            for col in 0..<9 {
                pencilMarkTotal += state.pencilMarks[row][col].count
                validOptionsTotal += state.validOptions[row][col].count
            }
        }
        // validOptions should generally have at least as many candidates as pencilMarks
        #expect(validOptionsTotal >= pencilMarkTotal, "validOptions should have at least as many candidates as user pencil marks")
    }

    @Test("Grid string and sudoku.coach produce same validOptions for same grid")
    func testConsistentValidOptionsAcrossFormats() throws {
        // Use a grid string that matches a known sudoku.coach puzzle's given digits
        let gridString = "413295678579846001628317459251764893347589000896123040130070000765030000980651000"

        let gridState = try BoardStateParser.parseGridString(gridString)

        let encoded = "SCv7_32_f2e7qjmh1b13037sisvav45496deslfvo0nhhb4cobc86jgv2jvtq5g75b4bg462snn951srppijp5brepuuln2kdpsjj5l9lgbteeu6814j96m4cim01a3404hkm8m1l1m2i14ec84g0b19a800c300m4910l90mgghja303leefbknfgve8u9u1j5lhhj1pnmh1u1t42qtllvsgdtaqpdvb7tejo09nh816k15gj6ofih0t8jftml1f496n1mdmv2v3upt6rrno0cjs13j4"

        let coachState = try BoardStateParser.parseSudokuCoach(encoded)

        // Both should produce identical validOptions since they share the same grid
        #expect(gridState.validOptions == coachState.validOptions, "Same grid should yield same validOptions regardless of parse format")
    }
}
