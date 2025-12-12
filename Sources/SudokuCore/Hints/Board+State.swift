//
//  Board+State.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

extension Board {
    public var state: BoardState {
        var pencilMarks: [[Set<Int>]] = Array(
            repeating: Array(repeating: [], count: 9),
            count: 9
        )
        var validOptions: [[Set<Int>]] = Array(
            repeating: Array(repeating: [], count: 9),
            count: 9
        )

        for row in 0..<9 {
            for col in 0..<9 {
                let cell = cell(at: .init(row: row, column: col))
                validOptions[row][col] = cell.validOptions
                pencilMarks[row][col] = cell.validOptions
                    .subtracting(cell.ruledOutCandidates)
            }
        }

        return BoardState(
            grid: self.currentGrid,
            pencilMarks: pencilMarks,
            validOptions: validOptions,
            solution: self.solution
        )
    }
}
