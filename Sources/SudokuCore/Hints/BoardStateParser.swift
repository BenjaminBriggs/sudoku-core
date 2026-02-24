//
//  BoardStateParser.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 24/02/2026.
//

import Compression
import Foundation

// MARK: - Format Detection

public enum BoardStringFormat: Sendable {
    /// Sudoku.coach encoded format (prefix "SCv7_32_")
    case sudokuCoach
    /// Sudoku.coach whole-progress format (prefix "32_")
    case sudokuCoachProgress
    /// 81-digit grid string (digits 0-9)
    case gridString81
}

// MARK: - Parse Errors

public enum BoardStateParseError: Error, Sendable {
    case unrecognizedFormat
    case invalidGridString
    case invalidBase32Character
    case zlibDecompressionFailed
    case invalidJSON
}

// MARK: - Parser

public enum BoardStateParser {

    /// Auto-detect format and parse a string into a `BoardState`.
    public static func parse(_ input: String) throws -> BoardState {
        guard let format = detectFormat(input) else {
            throw BoardStateParseError.unrecognizedFormat
        }

        switch format {
        case .sudokuCoach:
            return try parseSudokuCoach(input)
        case .sudokuCoachProgress:
            return try parseSudokuCoachProgress(input)
        case .gridString81:
            return try parseGridString(input)
        }
    }

    /// Detect the format of a board string, returns `nil` if unrecognised.
    public static func detectFormat(_ input: String) -> BoardStringFormat? {
        if input.hasPrefix("SCv7_32_") {
            return .sudokuCoach
        }

        // Check grid string before progress format to avoid mis-detecting
        // 81-character grids that happen to start with "32_"
        if input.count == 81, input.allSatisfy({ $0.isASCII }), input.contains(where: { ("1"..."9").contains($0) }) {
            return .gridString81
        }

        if input.hasPrefix("32_") {
            return .sudokuCoachProgress
        }

        return nil
    }

    // MARK: - Grid String

    /// Parse an 81-character grid string into a `BoardState`.
    /// Digits 1-9 are treated as cell values; any other character is treated as an empty cell.
    public static func parseGridString(_ input: String) throws -> BoardState {
        guard input.count == 81, input.allSatisfy({ $0.isASCII }), input.contains(where: { ("1"..."9").contains($0) }) else {
            throw BoardStateParseError.invalidGridString
        }

        let grid = Solution.cells(from: input)
        return BoardState.fromGrid(grid)
    }

    // MARK: - Sudoku.coach Format

    /// Parse a sudoku.coach encoded string into a `BoardState`.
    public static func parseSudokuCoach(_ encoded: String) throws -> BoardState {
        guard encoded.hasPrefix("SCv7_32_") else {
            throw BoardStateParseError.unrecognizedFormat
        }

        let payload = String(encoded.dropFirst("SCv7_32_".count))
        let jsonData = try decompressBase32Payload(payload)

        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw BoardStateParseError.invalidJSON
        }

        return try boardState(from: json)
    }

    /// Parse a sudoku.coach whole-progress encoded string into a `BoardState`.
    /// The progress format wraps state snapshots in `{"i": index, "a": [...], "b": [...]}`.
    public static func parseSudokuCoachProgress(_ encoded: String) throws -> BoardState {
        guard encoded.hasPrefix("32_") else {
            throw BoardStateParseError.unrecognizedFormat
        }

        let payload = String(encoded.dropFirst("32_".count))
        let jsonData = try decompressBase32Payload(payload)

        guard let wrapper = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let index = wrapper["i"] as? Int,
              let actions = wrapper["a"] as? [String],
              index >= 0, index < actions.count
        else {
            throw BoardStateParseError.invalidJSON
        }

        let stateString = actions[index]

        guard let stateData = stateString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: stateData) as? [String: Any]
        else {
            throw BoardStateParseError.invalidJSON
        }

        return try boardState(from: json)
    }

    // MARK: - Helpers

    /// Base32 decode and zlib decompress a payload string.
    static func decompressBase32Payload(_ payload: String) throws -> Data {
        let compressedData = try decodeBase32(payload)
        return try zlibDecompress(compressedData)
    }

    /// Build a `BoardState` from a sudoku.coach JSON dictionary containing
    /// `givenDigits` and `userCellCandidates` keys.
    static func boardState(from json: [String: Any]) throws -> BoardState {
        guard let givenDigits = json["givenDigits"] as? String,
              let candidatesString = json["userCellCandidates"] as? String
        else {
            throw BoardStateParseError.invalidJSON
        }

        // Parse the grid from givenDigits (81-char string of digits 0-9)
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for (i, ch) in givenDigits.enumerated() {
            guard i < 81, let digit = ch.wholeNumberValue else { continue }
            grid[i / 9][i % 9] = digit
        }

        // Parse candidate bitmasks (dash-separated integers)
        // Bit N represents candidate N (bit 1 = candidate 1, bit 9 = candidate 9)
        var pencilMarks = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
        let masks = candidatesString.split(separator: "-").map { Int($0) ?? 0 }

        for (i, mask) in masks.enumerated() {
            guard i < 81 else { break }
            let row = i / 9
            let col = i % 9

            if grid[row][col] > 0 {
                continue
            }

            var candidates = Set<Int>()
            for digit in 1...9 {
                if (mask & (1 << digit)) != 0 {
                    candidates.insert(digit)
                }
            }
            pencilMarks[row][col] = candidates
        }

        let validOptions = Validator.validOptions(for: grid)

        return BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: validOptions,
            solution: nil
        )
    }

    /// Decompress zlib-compressed data.
    static func zlibDecompress(_ data: Data) throws -> Data {
        // Strip 2-byte zlib header (e.g. 78 9C) — Apple's COMPRESSION_ZLIB expects raw deflate
        guard data.count > 2 else {
            throw BoardStateParseError.zlibDecompressionFailed
        }
        let strippedData = data.dropFirst(2)

        let bufferSize = 4096
        var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
        let inputBytes = Array(strippedData)

        let decompressedSize = inputBytes.withUnsafeBufferPointer { inputPointer in
            outputBuffer.withUnsafeMutableBufferPointer { outputPointer in
                compression_decode_buffer(
                    outputPointer.baseAddress!, bufferSize,
                    inputPointer.baseAddress!, inputBytes.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decompressedSize > 0 else {
            throw BoardStateParseError.zlibDecompressionFailed
        }

        return Data(outputBuffer.prefix(decompressedSize))
    }

    /// Base32hex decoder (RFC4648 Extended Hex Alphabet).
    /// Used by sudoku.coach: 0-9 a-v
    static func decodeBase32(_ input: String) throws -> Data {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuv")
        var lookup = [Character: Int]()
        for (i, ch) in alphabet.enumerated() {
            lookup[ch] = i
        }

        var buffer = [UInt8]()
        var bits = 0
        var value = 0

        for ch in input.lowercased() {
            guard let idx = lookup[ch] else {
                throw BoardStateParseError.invalidBase32Character
            }
            value = (value << 5) | idx
            bits += 5
            if bits >= 8 {
                bits -= 8
                buffer.append(UInt8((value >> bits) & 0xFF))
            }
        }

        return Data(buffer)
    }
}
