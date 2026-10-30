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
    /// How many solutions a grid has, as far as the search could tell.
    public enum Count: Sendable, Equatable {
        /// Every solution was counted.
        case exactly(Int)
        /// The search stopped before counting them all: at `solutionLimit` when there were too
        /// many, or lower when it gave up.
        case atLeast(Int)
    }

    /// What's known about one digit in one square.
    public enum Standing: Sendable, Equatable {
        /// In exactly this many solutions.
        case inSolutions(Int)
        /// In at least one solution, when the solutions weren't all counted.
        case inSomeSolutions
        /// In no solution. Every digit of a filled square reads this way.
        case inNoSolution
        /// The search gave up before it could tell.
        case undecided
    }

    public let solutionCount: Count
    /// Indexed by `index(of:at:)`.
    private let standings: [Standing]

    fileprivate init(solutionCount: Count, standings: [Standing]) {
        self.solutionCount = solutionCount
        self.standings = standings
    }

    fileprivate static func index(of digit: Int, at position: Puzzle.Index) -> Int {
        (position.row * 9 + position.column) * 9 + digit - 1
    }

    public func standing(of digit: Int, at position: Puzzle.Index) -> Standing {
        precondition((1...9).contains(digit), "Digits run from 1 to 9")
        return standings[Self.index(of: digit, at: position)]
    }

    /// The digits a square may still hold, which includes any the search gave up on.
    public func digits(at position: Puzzle.Index) -> [Int] {
        (1...9).filter { standing(of: $0, at: position) != .inNoSolution }
    }

    /// Clues that each leave exactly one solution, in row-major order. Empty unless the grid's
    /// solutions were all counted and there are at least two.
    public var finishingClues: [SuggestedClue] {
        guard case .exactly(let total) = solutionCount, total > 1 else { return [] }
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
    /// fewer than `solutionLimit`. Otherwise the digits the count reached are in a solution, and
    /// each digit left gets a search of its own. Every solution those find settles more digits.
    ///
    /// Clues that clash give no solutions. Cancelling the task stops the count and leaves the
    /// digits not yet searched `.undecided`.
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
            return TrueCandidates(solutionCount: .exactly(0), standings: standings)
        }
        let tally = search.tally(limit: solutionLimit, nodeLimit: nodeLimit / 2)

        if search.ranOut == false, tally.solutions < solutionLimit {
            for index in standings.indices where tally.counts[index] > 0 {
                standings[index] = .inSolutions(tally.counts[index])
            }
            return TrueCandidates(solutionCount: .exactly(tally.solutions), standings: standings)
        }

        let open = Puzzle.Index.allIndices.filter { grid[$0.row][$0.column] == 0 }
        let options = validOptions(for: grid)
        // Sorted so a spent budget gives up on the same digits every time.
        let legal = open.flatMap { position in
            options[position.row][position.column].sorted().map { (position: position, digit: $0) }
        }
        for (position, digit) in legal {
            let index = TrueCandidates.index(of: digit, at: position)
            standings[index] = tally.counts[index] > 0 ? .inSomeSolutions : .undecided
        }

        var budget = nodeLimit - search.nodes
        // A quick pass first, so a few hard digits can't spend the budget before the easy ones
        // get a turn.
        passes: for digitLimit in [nodeLimit / 400, nodeLimit / 20] {
            for (position, digit) in legal {
                let index = TrueCandidates.index(of: digit, at: position)
                guard standings[index] == .undecided else { continue }
                guard budget > 0, Task.isCancelled == false else { break passes }
                var trial = grid
                trial[position.row][position.column] = digit
                guard var check = BitsetSearch(grid: trial) else { continue }
                // Random digits, seeded for the same answer every time, give solutions unlike
                // each other, which settle far more digits than the lowest-first search would.
                let solution = check.firstSolution(
                    nodeLimit: min(budget, digitLimit),
                    random: SearchRandom(seed: UInt64(index))
                )
                budget -= check.nodes
                if let solution {
                    for other in open {
                        let found = TrueCandidates.index(of: solution[other.row][other.column], at: other)
                        standings[found] = .inSomeSolutions
                    }
                } else if check.ranOut == false {
                    standings[index] = .inNoSolution
                }
            }
        }
        return TrueCandidates(solutionCount: .atLeast(tally.solutions), standings: standings)
    }
}
