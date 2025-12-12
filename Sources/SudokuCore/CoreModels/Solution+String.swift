//
//  Solution+String.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//
import Foundation

extension Solution {
    public static func cells(from startingPositions: String) -> [[Int]] {
        var givenCells = Solution.empty()

        guard startingPositions.count == 81 else {
            return givenCells
        }

        let startingPositions = startingPositions.replacingOccurrences(of: "0", with: "#")

        for (index, character) in startingPositions.enumerated() {
            if let value = Int(String(character)) {
                let row = index / 9
                let col = index % 9
                givenCells[row][col] = value
            }
        }
        return givenCells
    }
}
