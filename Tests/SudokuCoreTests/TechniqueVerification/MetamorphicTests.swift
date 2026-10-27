//
//  MetamorphicTests.swift
//  SudokuCore
//
//  A sudoku stays the same puzzle under shuffled bands, rows within a band, stacks, columns
//  within a stack, transposition and relabelled digits. Every technique has to see the same
//  patterns after the board moves, which catches bugs that only show in one orientation.
//
import Foundation
import Testing
@testable import SudokuCore

/// A random symmetry of the sudoku grid, applied to cells and digits.
struct BoardTransform: CustomStringConvertible {
    /// `rows[old]` is the row an old row moves to; likewise for columns.
    let rows: [Int]
    let columns: [Int]
    let transposes: Bool
    /// `digits[old]` is the new digit; index 0 maps to 0 for empty cells.
    let digits: [Int]

    static func random(using rng: inout SplitMix64) -> BoardTransform {
        func linePermutation() -> [Int] {
            let bands = [0, 1, 2].shuffled(using: &rng)
            var result = Array(repeating: 0, count: 9)
            for (oldBand, newBand) in bands.enumerated() {
                let order = [0, 1, 2].shuffled(using: &rng)
                for offset in 0..<3 { result[oldBand * 3 + offset] = newBand * 3 + order[offset] }
            }
            return result
        }
        return BoardTransform(
            rows: linePermutation(),
            columns: linePermutation(),
            transposes: Bool.random(using: &rng),
            digits: [0] + Array(1...9).shuffled(using: &rng)
        )
    }

    var description: String { "rows \(rows) columns \(columns) transposed \(transposes) digits \(digits.dropFirst())" }

    func cell(_ position: Puzzle.Index) -> Puzzle.Index {
        let row = rows[position.row], column = columns[position.column]
        return transposes ? Puzzle.Index(row: column, column: row) : Puzzle.Index(row: row, column: column)
    }

    func apply(_ candidate: Reference.Candidate) -> Reference.Candidate {
        Reference.Candidate(cell(Puzzle.Index(row: candidate.row, column: candidate.column)), digits[candidate.digit])
    }

    func apply(_ state: BoardState) -> BoardState {
        func move<T>(_ grid: [[T]], _ value: (T) -> T, empty: T) -> [[T]] {
            var out = Array(repeating: Array(repeating: empty, count: 9), count: 9)
            for r in 0..<9 {
                for c in 0..<9 {
                    let target = cell(Puzzle.Index(row: r, column: c))
                    out[target.row][target.column] = value(grid[r][c])
                }
            }
            return out
        }
        let relabel = { (set: Set<Int>) in Set(set.map { digits[$0] }) }
        return BoardState(
            grid: move(state.grid, { digits[$0] }, empty: 0),
            pencilMarks: move(state.pencilMarks, relabel, empty: []),
            validOptions: move(state.validOptions, relabel, empty: []),
            solution: state.solution.map { move($0, { digits[$0] }, empty: 0) },
            assumesUniqueSolution: state.assumesUniqueSolution
        )
    }
}

struct MetamorphicTests {
    @Test("Every technique sees the same patterns after the board is shuffled, transposed or relabelled",
          arguments: CorpusSlice.selected)
    func transformsMoveHints(_ slice: CorpusSlice) {
        var rng = SplitMix64(seed: "metamorphic \(slice.part) " + slice.puzzle.id)
        var failures: [String] = []
        let techniques = TechniqueVerificationTests.techniques

        for (index, state) in slice.states(stride: 6) {
            let transform = BoardTransform.random(using: &rng)
            let moved = transform.apply(state)
            let before = Reference.licensedAll(techniques, in: state)
            let after = Reference.licensedAll(techniques, in: moved)

            for technique in techniques {
                let where_ = "\(technique.rawValue) state \(index) [\(transform)]"
                let expected = before[technique]!
                let actual = after[technique]!
                if Set(expected.eliminations.map(transform.apply)) != actual.eliminations
                    || Set(expected.placements.map(transform.apply)) != actual.placements {
                    failures.append("reference \(where_): licensed set doesn't move with the board")
                }

                let fired = HintFinder.findHint(for: technique, in: state) != nil
                let movedHint = HintFinder.findHint(for: technique, in: moved)
                if fired != (movedHint != nil) {
                    failures.append("\(where_): fires \(fired) before but \(movedHint != nil) after")
                }
                for action in movedHint?.actions ?? [] {
                    switch action.action {
                    case .ruleOut(let digit) where actual.eliminations.contains(Reference.Candidate(action.position, digit)) == false,
                         .solveAs(let digit) where actual.placements.contains(Reference.Candidate(action.position, digit)) == false:
                        failures.append("\(where_): \(action.debugDescription) isn't licensed on the moved board")
                    default:
                        break
                    }
                }
            }
        }

        #expect(failures.isEmpty, "\(failures.count) problems, first: \(failures.prefix(6).joined(separator: " | "))")
    }

    @Test("A stalled puzzle has nothing left for any technique's definition", arguments: CorpusPuzzle.selected)
    func stallsAreExhausted(_ puzzle: CorpusPuzzle) {
        var state = BoardState.fromGrid(puzzle.startingState, assumingUniqueSolution: true)
        while let hint = HintFinder.firstHint(in: state), hint.technique != .validation {
            state = state.applying(hint)
        }
        guard state.isSolved == false else { return }

        let licensed = Reference.licensedAll(TechniqueVerificationTests.techniques, in: state)
        let firing = licensed.filter { $0.value.isEmpty == false }.map(\.key.rawValue).sorted()
        #expect(firing.isEmpty, "stalled, yet the definitions of \(firing) still find something")
    }
}
