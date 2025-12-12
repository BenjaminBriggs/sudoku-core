//
//  Difficulty.swift
//  SudokuGenerator
//
//  Created by Benjamin Briggs on 15/02/2025.
//
import Foundation

extension PuzzleDifficulty.Level {

    public var cageSizeRange: ClosedRange<Int> {
        switch self {
        case .easy:
            return 3...5
        case .medium:
            return 2...5
        case .hard:
            return 2...9
        case .expert:
            return 2...9
        case .professional:
            return 2...9
        case .custom:
            return 4...9
        }
    }
}

extension PuzzleDifficulty: CustomDebugStringConvertible {
    public var debugDescription: String {
        self.level.debugDescription
    }
}

extension PuzzleDifficulty.Level: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .easy: return "Beginner"
        case .medium: return "Intermediate"
        case .hard: return "Advanced"
        case .expert: return "Expert"
        case .professional: return "Master"
        case .custom: return "Custom"
        }
    }
}
