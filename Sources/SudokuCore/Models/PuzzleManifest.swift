//
//  PuzzleManifest.swift
//  SudokuCore
//
//  Created by Claude on 03/10/2025.
//
import Foundation

/// Minimal manifest listing available puzzle batch URLs
/// Stored at: https://puzzles.yourdomain.com/V1/manifest.json
public struct PuzzleManifest: Codable, Sendable {
    public let easy: [String]
    public let medium: [String]
    public let hard: [String]
    public let expert: [String]
    public let professional: [String]

    public init(
        easy: [String] = [],
        medium: [String] = [],
        hard: [String] = [],
        expert: [String] = [],
        professional: [String] = []
    ) {
        self.easy = easy
        self.medium = medium
        self.hard = hard
        self.expert = expert
        self.professional = professional
    }

    /// Get batch paths for a specific difficulty level (relative paths)
    public func batchPaths(for difficulty: PuzzleDifficulty.Level) -> [String] {
        switch difficulty {
        case .easy: return easy
        case .medium: return medium
        case .hard: return hard
        case .expert: return expert
        case .professional: return professional
        case .custom: return []
        }
    }

    /// Get batch URLs for a specific difficulty level
    /// Note: Deprecated - use batchPaths(for:) and construct URLs with your base URL
    @available(*, deprecated, message: "Use batchPaths(for:) instead")
    public func batchURLs(for difficulty: PuzzleDifficulty.Level) -> [URL] {
        let urlStrings: [String] =
            switch difficulty {
            case .easy: easy
            case .medium: medium
            case .hard: hard
            case .expert: expert
            case .professional: professional
            case .custom: []
            }
        return urlStrings.compactMap { URL(string: $0) }
    }

    /// Get all URLs across all difficulties
    /// Note: Deprecated - use allBatchPaths and construct URLs with your base URL
    @available(*, deprecated, message: "Use allBatchPaths instead")
    public var allBatchURLs: [URL] {
        let strings: [String] = easy + medium + hard + expert + professional
        return strings.compactMap { URL(string: $0) }
    }

    /// Get all batch paths across all difficulties (relative paths)
    public var allBatchPaths: [String] {
        easy + medium + hard + expert + professional
    }

    /// Total number of batches across all difficulties
    public var totalBatches: Int {
        easy.count + medium.count + hard.count + expert.count + professional.count
    }
}
