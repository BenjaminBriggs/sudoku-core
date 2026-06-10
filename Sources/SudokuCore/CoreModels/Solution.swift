//
//  Solution.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//

public typealias Solution = [[Int]]
public typealias PencilMarks = [[Set<Int>]]

extension Solution {
    public static func randomNotValid() -> Solution {
        var solution = Solution.empty()
        for row in 0..<9 {
            for col in 0..<9 {
                solution[row][col] = Int.random(in: 1...9)
            }
        }
        return solution
    }

    public static func empty() -> Solution {
        return Solution(
            repeating: Array<Int>(
                repeating: 0,
                count: 9
            ),
            count: 9
        )
    }
}

extension PencilMarks {
    public static func empty() -> PencilMarks {
        return PencilMarks(
            repeating: Array<Set<Int>>(
                repeating: [],
                count: 9
            ),
            count: 9
        )
    }
}
extension Solution {
    public var exportString: String {
        return self.flatMap{$0}.map(String.init).joined()
    }
}

extension Solution {
    public func flatString(empty: String) -> String {
        self.map {
            $0.map {
                $0 == 0 ? empty : "\($0)"
            }.joined()
        }.joined()
    }
}
