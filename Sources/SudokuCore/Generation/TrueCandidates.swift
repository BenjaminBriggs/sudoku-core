//
//  TrueCandidates.swift
//  SudokuCore
//
//  The digits that are in at least one solution of a grid of clues, and how many solutions
//  hold each one: what a setter needs to choose a grid's last clues.
//
import Foundation

/// What a grid's solutions say about the digits of its empty squares.
///
/// A digit that doesn't clash in its row, column or box can still be in no solution. Near the
/// end of a build many are, and a digit in exactly one solution is a clue that finishes the
/// puzzle.
public struct TrueCandidates: Sendable, Equatable {
    /// What's known about one digit in one square.
    public enum Standing: Sendable, Equatable {
        /// In exactly this many solutions.
        case inSolutions(Int)
        /// In at least one solution, and there were too many to count.
        case inSomeSolutions
        /// In no solution. Every digit of a filled square reads this way.
        case inNoSolution
        /// The search gave up before it could tell.
        case undecided
    }

    /// How many solutions the grid has, or `nil` when there were too many to count.
    public let solutionCount: Int?
    /// Indexed `square * 9 + digit - 1`.
    private let standings: [Standing]

    fileprivate init(solutionCount: Int?, standings: [Standing]) {
        self.solutionCount = solutionCount
        self.standings = standings
    }

    public func standing(of digit: Int, at position: Puzzle.Index) -> Standing {
        standings[(position.row * 9 + position.column) * 9 + digit - 1]
    }

    /// The digits a square may still hold, which includes any the search gave up on.
    public func digits(at position: Puzzle.Index) -> [Int] {
        (1...9).filter { standing(of: $0, at: position) != .inNoSolution }
    }

    /// Clues that each leave exactly one solution, in row-major order. Empty unless the grid's
    /// solutions were all counted and there are at least two.
    public var finishingClues: [SuggestedClue] {
        guard let solutionCount, solutionCount > 1 else { return [] }
        return Puzzle.Index.allIndices.flatMap { position in
            (1...9)
                .filter { standing(of: $0, at: position) == .inSolutions(1) }
                .map { SuggestedClue(position: position, value: $0) }
        }
    }
}

extension Validator {
    /// Works out which digits of the grid's empty squares are in a solution.
    ///
    /// Counts the solutions first, tallying each digit, which answers everything when there are
    /// fewer than `solutionLimit`. Otherwise the tally has already found most digits, and each
    /// digit left gets a search of its own. Every solution those find rules in more digits.
    ///
    /// Clues that clash give no solutions. Cancelling the task leaves the digits not yet
    /// searched `.undecided`.
    ///
    /// - Parameters:
    ///   - solutionLimit: Solutions to count before settling for which digits are in any.
    ///   - nodeLimit: Branches the whole call may try, which bounds its time. Counting may use
    ///     half, and a single digit a twentieth. Digits past the limit are `.undecided`.
    public static func trueCandidates(
        of grid: [[Int]],
        solutionLimit: Int = 20_000,
        nodeLimit: Int = 400_000
    ) -> TrueCandidates {
        var standings = [TrueCandidates.Standing](repeating: .inNoSolution, count: 81 * 9)
        guard var search = BitsetSearch(grid: grid) else {
            return TrueCandidates(solutionCount: 0, standings: standings)
        }
        let tally = search.tally(limit: solutionLimit, nodeLimit: nodeLimit / 2)
        let open = Puzzle.Index.allIndices.filter { grid[$0.row][$0.column] == 0 }

        if search.ranOut == false, tally.solutions < solutionLimit {
            for position in open {
                let square = (position.row * 9 + position.column) * 9
                for digit in 0..<9 where tally.counts[square + digit] > 0 {
                    standings[square + digit] = .inSolutions(tally.counts[square + digit])
                }
            }
            return TrueCandidates(solutionCount: tally.solutions, standings: standings)
        }

        // Bitsets of digits, by square, in a solution and given up on. An answer can come from
        // a later digit's solution, so standings wait until every search has run.
        var inSolution = [Int](repeating: 0, count: 81)
        var gaveUp = [Int](repeating: 0, count: 81)
        for position in open {
            let square = position.row * 9 + position.column
            for digit in 0..<9 where tally.counts[square * 9 + digit] > 0 {
                inSolution[square] |= 1 << digit
            }
        }
        let options = validOptions(for: grid)
        var budget = nodeLimit - search.nodes
        for position in open {
            let square = position.row * 9 + position.column
            // Sorted so a spent budget gives up on the same digits every time.
            for digit in options[position.row][position.column].sorted() where inSolution[square] & (1 << (digit - 1)) == 0 {
                guard budget > 0, Task.isCancelled == false else {
                    gaveUp[square] |= 1 << (digit - 1)
                    continue
                }
                var trial = grid
                trial[position.row][position.column] = digit
                guard var check = BitsetSearch(grid: trial) else { continue }
                let solution = check.firstSolution(nodeLimit: min(budget, nodeLimit / 20), random: nil)
                budget -= check.nodes
                if let solution {
                    for other in open {
                        inSolution[other.row * 9 + other.column] |= 1 << (solution[other.row][other.column] - 1)
                    }
                } else if check.ranOut {
                    gaveUp[square] |= 1 << (digit - 1)
                }
            }
        }
        for position in open {
            let square = position.row * 9 + position.column
            for digit in 0..<9 {
                if inSolution[square] & (1 << digit) != 0 {
                    standings[square * 9 + digit] = .inSomeSolutions
                } else if gaveUp[square] & (1 << digit) != 0 {
                    standings[square * 9 + digit] = .undecided
                }
            }
        }
        return TrueCandidates(solutionCount: nil, standings: standings)
    }
}
