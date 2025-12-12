//
//  PuzzleServerConfig.swift
//  SudokuCore
//
//  Created by Claude on 03/10/2025.
//
import Foundation

/// Configuration for the puzzle distribution server
public struct PuzzleServerConfig: Sendable {
    public let baseURL: String
    public let version: String

    public init(baseURL: String, version: String = "V1") {
        self.baseURL = baseURL
        self.version = version
    }

    /// URL for the manifest file
    public var manifestURL: URL? {
        URL(string: "\(baseURL)/\(version)/manifest.json")
    }

    /// URL for a specific batch file
    public func batchURL(difficulty: PuzzleDifficulty.Level, batchNumber: Int) -> URL? {
        let filename = String(format: "batch-%03d.json", batchNumber)
        return URL(string: "\(baseURL)/\(version)/\(difficulty.rawValue)/\(filename)")
    }

    /// URL for a daily puzzle monthly file
    /// - Parameters:
    ///   - year: The year (e.g., 2025)
    ///   - month: The month (1-12)
    /// - Returns: URL for the monthly file at /V1/daily/YYYY/MM.json
    public func dailyPuzzleURL(year: Int, month: Int) -> URL? {
        let monthString = String(format: "%02d", month)
        return URL(string: "\(baseURL)/\(version)/daily/\(year)/\(monthString).json")
    }

    /// Production configuration for R2 public bucket
    /// Using R2 dev domain until magic-sudoku.app is configured
    public static let production = PuzzleServerConfig(
        baseURL: "https://pub-31edef8e8ee54f5fb040c5e66e2a4bc7.r2.dev"
    )
}
