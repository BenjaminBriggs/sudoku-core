//
//  ListFormatting.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

extension Collection where Element == Int {
    public func formattedList() -> String {
        let listFormatter = ListFormatter()
        return listFormatter.string(from: map(String.init))!
    }
}
extension Collection where Element == String {
    public func formattedList() -> String {
        let listFormatter = ListFormatter()
        return listFormatter.string(from: self as! [Any])!
    }
}
extension Collection where Element == Puzzle.Index {
    public func formattedList() -> String {
        let listFormatter = ListFormatter()
        return listFormatter.string(from: map(\.description))!
    }
}
