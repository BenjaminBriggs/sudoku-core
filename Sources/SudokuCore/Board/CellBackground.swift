//
//  Background.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 25/02/2025.
//
import Foundation

extension Board.Cell {
    public enum Background: Int, Codable, Sendable {
        case red = 1
        case green = 2
        case blue = 3
        case yellow = 4
        case purple = 5
        case orange = 6
        case pink = 7
        case brown = 8
        case clear = 9

        public init(from number: Int) {
            if number == 0 {
                self = .clear
            } else {
                self.init(rawValue: min(abs(number), 9))!
            }
        }
    }
}
