//
//  BoardState.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

public struct BoardState: Sendable, Equatable {
    public var grid: [[Int]]
    public var pencilMarks: [[Set<Int>]]
    public var validOptions: [[Set<Int>]]
    public var solution: [[Int]]?

    public init(
        grid: [[Int]] = [],
        pencilMarks: [[Set<Int>]] = [],
        validOptions: [[Set<Int>]] = [],
        solution: [[Int]]? = nil
    ) {
        self.grid = grid
        self.pencilMarks = pencilMarks
        self.validOptions = validOptions
        self.solution = solution
    }
}

// MARK: - Sudoku.coach Format Decoder

public enum BoardStateDecodeError: Error {
    case invalidPrefix
    case invalidEncoding
    case insufficientBits
    case invalidCharacter
}

extension BoardState {
    /// Initialize a board from a sudoku.coach-style encoded string
    /// Format: SCv7_32_{base32-encoded-data}
    /// The data contains 9 bits per cell (one bit per candidate 1-9)
    public init(sudokuCoachString encoded: String) throws {
        guard encoded.hasPrefix("SCv7_32_") else {
            throw BoardStateDecodeError.invalidPrefix
        }

        let payload = String(encoded.dropFirst("SCv7_32_".count))

        // Base32 decode
        let data = try Self.decodeBase32(payload)

        // Turn into bit array
        var bits: [Bool] = []
        for byte in data {
            for i in (0..<8).reversed() {
                bits.append((byte & (1 << i)) != 0)
            }
        }

        guard bits.count >= 81 * 9 else {
            throw BoardStateDecodeError.insufficientBits
        }

        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        var pencilMarks = Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)

        var idx = 0
        for row in 0..<9 {
            for col in 0..<9 {
                var mask = 0
                for i in 0..<9 {
                    if bits[idx] { mask |= (1 << i) }
                    idx += 1
                }
                let candidates = (1...9).filter { (mask & (1 << ($0 - 1))) != 0 }
                if candidates.count == 1 {
                    grid[row][col] = candidates[0]
                } else {
                    grid[row][col] = 0
                    pencilMarks[row][col] = Set(candidates)
                }
            }
        }

        self.init(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks,
            solution: nil
        )
    }

    /// Base32hex decoder (RFC4648 Extended Hex Alphabet)
    /// Used by sudoku.coach: 0-9 a-v
    private static func decodeBase32(_ input: String) throws -> Data {
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
                throw BoardStateDecodeError.invalidCharacter
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
