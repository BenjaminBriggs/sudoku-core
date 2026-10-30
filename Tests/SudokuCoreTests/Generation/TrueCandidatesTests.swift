//
//  TrueCandidatesTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct TrueCandidatesTests {
    /// A unique 30-clue puzzle (the classic Wikipedia example).
    let unique: [[Int]] = Solution.cells(
        from: "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    )

    /// The unique puzzle less four clues, which leaves four solutions.
    var several: [[Int]] {
        var grid = unique
        for (row, column) in [(0, 4), (1, 0), (1, 3), (3, 4)] {
            grid[row][column] = 0
        }
        return grid
    }

    private func open(in grid: [[Int]]) -> [Puzzle.Index] {
        Puzzle.Index.allIndices.filter { grid[$0.row][$0.column] == 0 }
    }

    private func placing(_ digit: Int, at position: Puzzle.Index, in grid: [[Int]]) -> [[Int]] {
        var trial = grid
        trial[position.row][position.column] = digit
        return trial
    }

    // MARK: - Counted

    @Test func countsMatchCountingEachDigitAlone() {
        let candidates = Validator.trueCandidates(of: several)
        for position in open(in: several) {
            for digit in 1...9 {
                let solutions = Validator.countSolutions(of: placing(digit, at: position, in: several), limit: 100_000)
                let expected: TrueCandidates.Standing = solutions == 0 ? .inNoSolution : .inSolutions(solutions)
                #expect(candidates.standing(of: digit, at: position) == expected)
            }
        }
    }

    @Test func eachSquaresCountsAddUpToTheSolutions() {
        let candidates = Validator.trueCandidates(of: several)
        #expect(candidates.solutionCount == .exactly(4))
        for position in open(in: several) {
            let counts = (1...9).map { digit -> Int in
                if case .inSolutions(let count) = candidates.standing(of: digit, at: position) { return count }
                return 0
            }
            #expect(counts.reduce(0, +) == 4)
        }
    }

    @Test func aUniqueGridHasOneDigitPerSquareAndNothingToFinish() {
        let candidates = Validator.trueCandidates(of: unique)
        #expect(candidates.solutionCount == .exactly(1))
        for position in open(in: unique) {
            #expect(candidates.digits(at: position).count == 1)
        }
        #expect(candidates.finishingClues.isEmpty)
    }

    @Test func finishingCluesEachLeaveOneSolution() {
        let candidates = Validator.trueCandidates(of: several)
        #expect(candidates.finishingClues.isEmpty == false)
        for clue in candidates.finishingClues {
            #expect(Validator.solutionCount(of: placing(clue.value, at: clue.position, in: several)).isUnique)
        }
    }

    @Test func filledSquaresHoldNothing() {
        let candidates = Validator.trueCandidates(of: several)
        let clue = Puzzle.Index(row: 2, column: 1)
        #expect(several[clue.row][clue.column] == 9)
        #expect(candidates.digits(at: clue).isEmpty)
    }

    // MARK: - Too many to count

    @Test func pastTheLimitEveryDigitIsStillRight() {
        let candidates = Validator.trueCandidates(of: several, solutionLimit: 2)
        #expect(candidates.solutionCount == .atLeast(2))
        #expect(candidates.finishingClues.isEmpty)
        for position in open(in: several) {
            for digit in 1...9 {
                let solvable = Validator.countSolutions(of: placing(digit, at: position, in: several), limit: 1) > 0
                #expect(candidates.standing(of: digit, at: position) == (solvable ? .inSomeSolutions : .inNoSolution))
            }
        }
    }

    @Test func anEmptyGridHasEveryDigitEverywhere() {
        let candidates = Validator.trueCandidates(of: .empty(), solutionLimit: 200)
        #expect(candidates.solutionCount == .atLeast(200))
        for position in Puzzle.Index.allIndices {
            for digit in 1...9 {
                #expect(candidates.standing(of: digit, at: position) == .inSomeSolutions)
            }
        }
    }

    // MARK: - No solutions

    @Test func clashingCluesHaveNoSolutions() {
        var grid = unique
        grid[0][2] = 5 // Repeats the 5 in row 0.
        let candidates = Validator.trueCandidates(of: grid)
        #expect(candidates.solutionCount == .exactly(0))
        #expect(open(in: grid).allSatisfy { candidates.digits(at: $0).isEmpty })
        #expect(candidates.finishingClues.isEmpty)
    }

    @Test func cluesNoGridCompletesHaveNoSolutions() {
        var grid: [[Int]] = .empty()
        grid[0] = [1, 2, 3, 4, 5, 6, 7, 8, 0]
        grid[1][8] = 9 // Leaves row 0's last square with no digit.
        let candidates = Validator.trueCandidates(of: grid)
        #expect(candidates.solutionCount == .exactly(0))
        #expect(open(in: grid).allSatisfy { candidates.digits(at: $0).isEmpty })
    }

    // MARK: - Giving up

    @Test func aSpentBudgetLeavesDigitsUndecided() {
        let candidates = Validator.trueCandidates(of: .empty(), nodeLimit: 2)
        #expect(candidates.solutionCount == .atLeast(0))
        for position in Puzzle.Index.allIndices {
            #expect(candidates.standing(of: 5, at: position) == .undecided)
            #expect(candidates.digits(at: position) == Array(1...9))
        }
    }

    @Test func aCountThatGivesUpIsNotTooManyToCount() {
        let candidates = Validator.trueCandidates(of: several, nodeLimit: 20)
        #expect(candidates.solutionCount == .atLeast(0))
        #expect(candidates.finishingClues.isEmpty)
    }

    @Test func givingUpOnADigitNeverRulesItOut() {
        // Too few branches for a digit's search to reach a solution, with budget to try them all.
        let candidates = Validator.trueCandidates(of: several, solutionLimit: 1, nodeLimit: 400)
        var undecided = 0
        for position in open(in: several) {
            for digit in Validator.validOptions(for: several)[position.row][position.column] {
                let standing = candidates.standing(of: digit, at: position)
                if standing == .undecided { undecided += 1 }
                let solvable = Validator.countSolutions(of: placing(digit, at: position, in: several), limit: 1) > 0
                #expect(standing != (solvable ? .inNoSolution : .inSomeSolutions))
            }
        }
        #expect(undecided > 0)
    }

    @Test func aDigitGivenUpOnIsSettledByALaterPass() {
        // The quick pass gets 10 branches a digit, too few to reach a solution; the second gets 200.
        let candidates = Validator.trueCandidates(of: several, solutionLimit: 1, nodeLimit: 4_000)
        for position in open(in: several) {
            for digit in 1...9 {
                let solvable = Validator.countSolutions(of: placing(digit, at: position, in: several), limit: 1) > 0
                #expect(candidates.standing(of: digit, at: position) == (solvable ? .inSomeSolutions : .inNoSolution))
            }
        }
    }

    @Test func aSpentBudgetGivesTheSameAnswerEveryTime() {
        // The bottom six rows of the puzzle. This budget runs out partway through the digits, so
        // which ones it reaches decides the answer.
        let sparse = Solution.cells(
            from: "000000000000000000000000000800060003400803001700020006060000280000419005000080079"
        )
        let first = Validator.trueCandidates(of: sparse, solutionLimit: 50, nodeLimit: 2_000)
        let standings = open(in: sparse).flatMap { position in (1...9).map { first.standing(of: $0, at: position) } }
        #expect(standings.contains(.undecided))
        #expect(standings.contains(.inSomeSolutions))
        #expect(Validator.trueCandidates(of: sparse, solutionLimit: 50, nodeLimit: 2_000) == first)
    }

    @Test func cancellingLeavesDigitsUndecidedNotRuledOut() async {
        let grid = several
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Validator.trueCandidates(of: grid, solutionLimit: 1)
        }
        let candidates = await task.value
        let options = Validator.validOptions(for: grid)
        let standings = open(in: grid).flatMap { position in
            options[position.row][position.column].map { candidates.standing(of: $0, at: position) }
        }
        #expect(standings.contains(.undecided))
        #expect(standings.contains(.inNoSolution) == false)
    }

    @Test func cancellingStopsTheCount() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Validator.trueCandidates(of: .empty())
        }
        let candidates = await task.value
        guard case .atLeast(let found) = candidates.solutionCount else {
            Issue.record("Expected an unfinished count")
            return
        }
        #expect(found < 20_000)
    }

    @Test func aSearchUsedAgainStartsAfresh() throws {
        var search = try #require(BitsetSearch(grid: several))
        _ = search.tally(limit: 1, nodeLimit: 1)
        #expect(search.ranOut)
        #expect(search.count(limit: 100) == 4)
        #expect(search.ranOut == false)
    }

    @Test func theSameGridGivesTheSameAnswer() {
        #expect(Validator.trueCandidates(of: several) == Validator.trueCandidates(of: several))
        #expect(Validator.trueCandidates(of: several, solutionLimit: 2) == Validator.trueCandidates(of: several, solutionLimit: 2))
    }
}
