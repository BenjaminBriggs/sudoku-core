//
//  MonthlyPuzzleManifest.swift
//  SudokuCore
//
//  Created by Claude on 04/10/2025.
//
import Foundation

/// Represents a month's worth of daily puzzles
/// Stored at: /V1/daily/YYYY/MM.json (e.g., /V1/daily/2025/01.json)
public struct MonthlyPuzzleManifest: Codable, Sendable {
    /// Month identifier in format "YYYY-MM" (e.g., "2025-01")
    public let month: String

    /// Array of daily puzzles for the month
    public let puzzles: [DailyPuzzleEntry]

    public init(month: String, puzzles: [DailyPuzzleEntry]) {
        self.month = month
        self.puzzles = puzzles
    }

    /// Get puzzle for a specific date
    public func puzzle(for date: Date) -> Puzzle? {
        let calendar = Calendar.current
        return puzzles.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        })?.puzzle
    }

    /// Get puzzle for a specific date string in format "YYYY-MM-DD"
    public func puzzle(for dateString: String) -> Puzzle? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        guard let date = formatter.date(from: dateString) else {
            return nil
        }

        return puzzle(for: date)
    }

    /// Check if all dates in the month are present (28-31 depending on month)
    public var isComplete: Bool {
        guard let firstDate = puzzles.first?.date else {
            return false
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: firstDate)

        guard let year = components.year, let month = components.month else {
            return false
        }

        let expectedCount = daysInMonth(year: year, month: month)
        return puzzles.count == expectedCount
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = calendar.date(from: components),
            let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return 0
        }

        return range.count
    }
}

/// Individual daily puzzle entry
public struct DailyPuzzleEntry: Codable, Sendable {
    /// The date for this puzzle
    public let date: Date

    /// The puzzle for this date
    public let puzzle: Puzzle

    public init(date: Date, puzzle: Puzzle) {
        self.date = date
        self.puzzle = puzzle
    }

    /// Create from string date in format "YYYY-MM-DD"
    public init?(dateString: String, puzzle: Puzzle) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        guard let date = formatter.date(from: dateString) else {
            return nil
        }

        self.date = date
        self.puzzle = puzzle
    }

    /// Get date string in format "YYYY-MM-DD"
    public var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // Custom Codable implementation to maintain JSON compatibility with string dates
    enum CodingKeys: String, CodingKey {
        case date
        case puzzle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Invalid date format. Expected yyyy-MM-dd"
            )
        }

        self.date = date
        self.puzzle = try container.decode(Puzzle.self, forKey: .puzzle)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        try container.encode(formatter.string(from: date), forKey: .date)
        try container.encode(puzzle, forKey: .puzzle)
    }
}
