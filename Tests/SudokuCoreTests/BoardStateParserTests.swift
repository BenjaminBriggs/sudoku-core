//
//  BoardStateParserTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 02/10/2025.
//

import Compression
import Foundation
import Testing
@testable import SudokuCore

struct BoardStateParserTests {

    // MARK: - Sudoku.coach Decoding Tests

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

    // MARK: - Sudoku.coach Progress Format Tests

    @Test("Decode sudoku.coach progress format - grid matches base puzzle")
    func testSudokuCoachProgressDecoder() throws {
        let wholeProgress = "32_f2e5b461db1j0346rt2ue634p6beqn5r6vc73rh14ej1gig697ds6imvnlp55lmcg9fvsvo9fvg3ml78m61g3uhfn1jrh5bpl4vl71huegckssot7vlmukcrjamrecjtqh9rqb4qch0f4c910s8kcf99r9j127bphr4i41m1s18lg9rd051v9718k13p852l2chbj80qi2mee32an4n6afkkufsj0j333m3knmb06od7plfelb33igr8b260rcmfn6kmh76s5pnaberefe171nvuhg125698vs3umk1mnpukf2n0in2k89lsb58h6rnbjen9bo81os7bttdnhu7ifb90an30"

        let state = try BoardStateParser.parseSudokuCoachProgress(wholeProgress)

        let expectedGrid = "025890376630000981890300425389100760750639810000078539270500698500900247900702153"

        for (i, ch) in expectedGrid.enumerated() {
            let digit = Int(String(ch))!
            let row = i / 9
            let col = i % 9
            #expect(
                state.grid[row][col] == digit,
                "Cell (\(row),\(col)) should be \(digit), got \(state.grid[row][col])"
            )
        }
    }

    @Test("Decode sudoku.coach progress format - pencil marks present")
    func testSudokuCoachProgressDecoderPencilMarks() throws {
        let wholeProgress = "32_f2e5b461db1j0346rt2ue634p6beqn5r6vc73rh14ej1gig697ds6imvnlp55lmcg9fvsvo9fvg3ml78m61g3uhfn1jrh5bpl4vl71huegckssot7vlmukcrjamrecjtqh9rqb4qch0f4c910s8kcf99r9j127bphr4i41m1s18lg9rd051v9718k13p852l2chbj80qi2mee32an4n6afkkufsj0j333m3knmb06od7plfelb33igr8b260rcmfn6kmh76s5pnaberefe171nvuhg125698vs3umk1mnpukf2n0in2k89lsb58h6rnbjen9bo81os7bttdnhu7ifb90an30"

        let state = try BoardStateParser.parseSudokuCoachProgress(wholeProgress)

        // Cell (0,0) is given digit 0 (empty) — should have pencil marks
        #expect(state.grid[0][0] == 0, "Cell (0,0) should be empty")
        #expect(state.pencilMarks[0][0].isEmpty == false, "Empty cell should have pencil marks")

        // Cell (0,1) is given digit 2 — should have no pencil marks
        #expect(state.grid[0][1] == 2, "Cell (0,1) should be 2")
        #expect(state.pencilMarks[0][1].isEmpty, "Filled cell should have no pencil marks")
    }

    @Test("Decode sudoku.coach progress format - produces same result as SCv7 for same puzzle")
    func testSudokuCoachProgressMatchesSCv7() throws {
        let scv7 = "SCv7_32_f2e5ajebdb1j047s2uei667d9atqmn6j7vk1e61chgge94547kie9ntrm95u6qj0khsq0uc6sndefjvud3glg3r1t7fursmhitvbv1b300aqmo0lc7saj5k60gp1bdkq00amh0dg4uhg1de2ika0b43apoaq1b6e1958bgp1fjetltekprjt6t4pvcudrmoo98bf32utqd2st48gb5h55mfr7hcdpbjpcs7ngdrfbs8fdlsvu00q6q7i7tc47mfmqfdv42aumuc2hqjrpfee2kevf12nhv808fgkfd8"
        let wholeProgress = "32_f2e5b461db1j0346rt2ue634p6beqn5r6vc73rh14ej1gig697ds6imvnlp55lmcg9fvsvo9fvg3ml78m61g3uhfn1jrh5bpl4vl71huegckssot7vlmukcrjamrecjtqh9rqb4qch0f4c910s8kcf99r9j127bphr4i41m1s18lg9rd051v9718k13p852l2chbj80qi2mee32an4n6afkkufsj0j333m3knmb06od7plfelb33igr8b260rcmfn6kmh76s5pnaberefe171nvuhg125698vs3umk1mnpukf2n0in2k89lsb58h6rnbjen9bo81os7bttdnhu7ifb90an30"

        let scv7State = try BoardStateParser.parseSudokuCoach(scv7)
        let progressState = try BoardStateParser.parseSudokuCoachProgress(wholeProgress)

        // Both should decode the same grid
        #expect(scv7State.grid == progressState.grid, "Grid should match between SCv7 and progress format")

        // Both should compute the same validOptions from the same grid
        #expect(scv7State.validOptions == progressState.validOptions, "validOptions should match")
    }

    @Test("parseSudokuCoachProgress rejects strings without 32_ prefix")
    func testSudokuCoachProgressRejectsInvalidPrefix() {
        #expect(throws: BoardStateParseError.unrecognizedFormat) {
            try BoardStateParser.parseSudokuCoachProgress("INVALID_PREFIX_abc123")
        }
    }

    @Test("parse auto-detects sudoku.coach progress format")
    func testParseAutoDetectsProgress() throws {
        let wholeProgress = "32_f2e5b461db1j0346rt2ue634p6beqn5r6vc73rh14ej1gig697ds6imvnlp55lmcg9fvsvo9fvg3ml78m61g3uhfn1jrh5bpl4vl71huegckssot7vlmukcrjamrecjtqh9rqb4qch0f4c910s8kcf99r9j127bphr4i41m1s18lg9rd051v9718k13p852l2chbj80qi2mee32an4n6afkkufsj0j333m3knmb06od7plfelb33igr8b260rcmfn6kmh76s5pnaberefe171nvuhg125698vs3umk1mnpukf2n0in2k89lsb58h6rnbjen9bo81os7bttdnhu7ifb90an30"

        let state = try BoardStateParser.parse(wholeProgress)
        #expect(state.grid[0][1] == 2, "Should parse correctly via auto-detect")
    }

    // MARK: - Format Detection Tests

    @Test("detectFormat identifies sudoku.coach strings")
    func testDetectFormatSudokuCoach() {
        let format = BoardStateParser.detectFormat("SCv7_32_abc123")
        #expect(format == .sudokuCoach)
    }

    @Test("detectFormat identifies sudoku.coach progress strings")
    func testDetectFormatSudokuCoachProgress() {
        let format = BoardStateParser.detectFormat("32_abc123")
        #expect(format == .sudokuCoachProgress)
    }

    @Test("detectFormat identifies 81-character grid strings with various empty markers")
    func testDetectFormatGridString() {
        // Zeros for empties
        let zeros = "000000000000000000000000000000000000000000283000000154000000000000000070000000090"
        #expect(BoardStateParser.detectFormat(zeros) == .gridString81)

        // Dots for empties
        let dots = "..........................................283......154................7.......9.."
        #expect(BoardStateParser.detectFormat(dots) == .gridString81)

        // Asterisks for empties
        let stars = "******************************************283******154****************7*******9**"
        #expect(BoardStateParser.detectFormat(stars) == .gridString81)
    }

    @Test("detectFormat returns nil for unrecognised input")
    func testDetectFormatUnrecognised() {
        #expect(BoardStateParser.detectFormat("") == nil)
        #expect(BoardStateParser.detectFormat("too short") == nil)
        #expect(BoardStateParser.detectFormat("not a valid format at all and definitely not 81 digits") == nil)
        // 81 characters but no digits 1-9
        #expect(BoardStateParser.detectFormat("abcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghiabcdefghi") == nil)
        #expect(BoardStateParser.detectFormat("000000000000000000000000000000000000000000000000000000000000000000000000000000000") == nil)
    }

    @Test("detectFormat prefers gridString81 over progress format for 81-char strings starting with 32_")
    func testDetectFormatGridStringStartingWith32() throws {
        // 81-char grid that happens to start with "32_" (underscore as empty marker)
        let grid = "32_...6.8..7..95..1.83..4.5389100760750639810...078539270500698500900247900702153"

        #expect(BoardStateParser.detectFormat(grid) == .gridString81)

        let state = try BoardStateParser.parse(grid)
        #expect(state.grid[0][0] == 3)
        #expect(state.grid[0][1] == 2)
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

    @Test("parseGridString handles dots as empty cells")
    func testParseGridStringDots() throws {
        let dotGrid = "..........................................283......154................7.......9.."

        let state = try BoardStateParser.parseGridString(dotGrid)

        #expect(state.grid[4][6] == 2)
        #expect(state.grid[4][7] == 8)
        #expect(state.grid[4][8] == 3)
        #expect(state.grid[0][0] == 0, "Dot should be treated as empty")
    }

    @Test("parseGridString handles mixed empty markers")
    func testParseGridStringMixedMarkers() throws {
        // Build from the zero-based string, replacing 0s with alternating . and *
        let zeroGrid = "000000000000000000000000000000000000000000283000000154000000000000000070000000090"
        let markers: [Character] = [".", "*"]
        var markerIndex = 0
        let mixed = String(zeroGrid.map { ch -> Character in
            if ch == "0" {
                let marker = markers[markerIndex % markers.count]
                markerIndex += 1
                return marker
            }
            return ch
        })

        let state = try BoardStateParser.parseGridString(mixed)

        #expect(state.grid[4][6] == 2)
        #expect(state.grid[4][7] == 8)
        #expect(state.grid[4][8] == 3)
    }

    @Test("parseGridString rejects invalid input")
    func testParseGridStringInvalid() {
        #expect(throws: BoardStateParseError.invalidGridString) {
            try BoardStateParser.parseGridString("123")
        }
        // 81 characters but no digits 1-9
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

    // MARK: - zlibDecompress Tests

    @Test("zlibDecompress decompresses valid zlib data")
    func testZlibDecompressValidData() throws {
        let original = Array("Hello, World!".utf8)

        // Compress with raw deflate
        let compressedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { compressedBuffer.deallocate() }

        let compressedSize = original.withUnsafeBufferPointer { inputPointer in
            compression_encode_buffer(
                compressedBuffer, 4096,
                inputPointer.baseAddress!, original.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        #expect(compressedSize > 0, "Compression should succeed")

        // Prepend the 2-byte zlib header that zlibDecompress expects to strip
        var zlibData = Data([0x78, 0x9C])
        zlibData.append(Data(bytes: compressedBuffer, count: compressedSize))

        let decompressed = try BoardStateParser.zlibDecompress(zlibData)
        let result = String(data: decompressed, encoding: .utf8)
        #expect(result == "Hello, World!", "Decompressed data should match original")
    }

    @Test("zlibDecompress throws for data too short to contain zlib header")
    func testZlibDecompressTooShort() {
        #expect(throws: BoardStateParseError.zlibDecompressionFailed) {
            try BoardStateParser.zlibDecompress(Data([0x78]))
        }
        #expect(throws: BoardStateParseError.zlibDecompressionFailed) {
            try BoardStateParser.zlibDecompress(Data([0x78, 0x9C]))
        }
        #expect(throws: BoardStateParseError.zlibDecompressionFailed) {
            try BoardStateParser.zlibDecompress(Data())
        }
    }

    @Test("zlibDecompress throws for invalid compressed payload")
    func testZlibDecompressInvalidPayload() {
        // Valid 2-byte header followed by garbage data
        let invalidData = Data([0x78, 0x9C, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: BoardStateParseError.zlibDecompressionFailed) {
            try BoardStateParser.zlibDecompress(invalidData)
        }
    }
}
