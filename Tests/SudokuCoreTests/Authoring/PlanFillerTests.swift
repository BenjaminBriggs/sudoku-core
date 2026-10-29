//
//  PlanFillerTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct PlanFillerTests {
    /// Unique, 180° symmetric, solved by singles and Pointing.
    let puzzle: [[Int]] = Solution.cells(
        from: "020608000580009700000040000370000500600000004008000013000020000009800036000306090"
    )

    var plan: Set<Puzzle.Index> {
        Set(Puzzle.Index.allIndices.filter { puzzle[$0.row][$0.column] != 0 })
    }

    var solution: Solution {
        guard case .unique(let solution) = Validator.solutionCount(of: puzzle) else { fatalError("Fixture isn't unique") }
        return solution
    }

    // MARK: - Closed plans

    @Test func emptyLinesInABandCanSwap() {
        let plan = Set(Puzzle.Index.allIndices.filter { $0.row >= 2 })
        let lines = PlanFiller.swappableLines(in: plan)
        #expect(lines.contains(PlanFiller.SwappableLines(kind: .rows, lines: [0, 1])))
    }

    @Test func emptyColumnsInAStackCanSwap() {
        let plan = Set(Puzzle.Index.allIndices.filter { $0.column != 6 && $0.column != 8 })
        #expect(PlanFiller.swappableLines(in: plan) == [PlanFiller.SwappableLines(kind: .columns, lines: [6, 8])])
    }

    @Test func aRealPuzzlesPlanIsOpen() {
        #expect(PlanFiller.swappableLines(in: plan).isEmpty)
    }

    // MARK: - Accepting a fill

    @Test func acceptsThePuzzleForItsOwnPlan() {
        #expect(PlanFiller.accepts(puzzle, for: PlanFiller.Request(plan: plan)))
    }

    @Test func refusesAClueOutsideThePlan() {
        var grid = puzzle
        let outside = Puzzle.Index.allIndices.first { puzzle[$0.row][$0.column] == 0 }!
        grid[outside.row][outside.column] = solution[outside.row][outside.column]
        #expect(PlanFiller.accepts(grid, for: PlanFiller.Request(plan: plan)) == false)
    }

    @Test func refusesAChangedPlacedClue() {
        var clues = Solution.empty()
        let first = plan.sorted { ($0.row, $0.column) < ($1.row, $1.column) }[0]
        clues[first.row][first.column] = puzzle[first.row][first.column] % 9 + 1
        #expect(PlanFiller.accepts(puzzle, for: PlanFiller.Request(plan: plan, clues: clues)) == false)
    }

    @Test func refusesSeveralSolutions() {
        var grid = puzzle
        for position in plan.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }).prefix(8) {
            grid[position.row][position.column] = 0
        }
        #expect(PlanFiller.accepts(grid, for: PlanFiller.Request(plan: plan)) == false)
    }

    @Test func refusesAPathWithoutTheRecordedSteps() {
        let request = PlanFiller.Request(plan: plan, recorded: [RecordedStep(technique: .xWing)])
        #expect(PlanFiller.accepts(puzzle, for: request) == false)
        let pointing = PlanFiller.Request(plan: plan, recorded: [RecordedStep(technique: .lockedCandidatesPointing)])
        #expect(PlanFiller.accepts(puzzle, for: pointing))
    }

    @Test func refusesAPuzzleBeyondTheCeiling() {
        #expect(PlanFiller.accepts(puzzle, for: PlanFiller.Request(plan: plan, ceiling: .easy)) == false)
    }

    // MARK: - Filling

    @Test func fillsAnEmptyPlan() throws {
        let request = PlanFiller.Request(plan: plan)
        var generator = SearchRandom(seed: 3)
        let filled = try #require(PlanFiller.fill(request, using: &generator, maxMoves: 50_000))
        #expect(PlanFiller.accepts(filled, for: request))
    }

    @Test func keepsThePlacedClues() throws {
        var clues = Solution.empty()
        for position in plan.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }).prefix(10) {
            clues[position.row][position.column] = puzzle[position.row][position.column]
        }
        let request = PlanFiller.Request(plan: plan, clues: clues)
        var generator = SearchRandom(seed: 5)
        let filled = try #require(PlanFiller.fill(request, using: &generator, maxMoves: 50_000))
        #expect(PlanFiller.accepts(filled, for: request))
    }

    @Test func sameSeedSameFill() {
        let request = PlanFiller.Request(plan: plan)
        var first = SearchRandom(seed: 11)
        var second = SearchRandom(seed: 11)
        #expect(PlanFiller.fill(request, using: &first) == PlanFiller.fill(request, using: &second))
    }

    @Test func aFullyPlacedPlanFillsAsItIs() {
        let request = PlanFiller.Request(plan: plan, clues: puzzle, recorded: [RecordedStep(technique: .lockedCandidatesPointing)])
        var generator = SearchRandom(seed: 1)
        #expect(PlanFiller.fill(request, using: &generator, maxMoves: 10) == puzzle)
    }

    @Test func aClosedPlanNeverFills() {
        let closed = Set(Puzzle.Index.allIndices.filter { $0.row >= 2 && ($0.row + $0.column).isMultiple(of: 3) })
        var generator = SearchRandom(seed: 2)
        #expect(PlanFiller.fill(PlanFiller.Request(plan: closed), using: &generator, maxMoves: 300) == nil)
    }

    @Test func relaxingBringsBackASkippedStep() throws {
        // Every orbit the puzzle leaves empty is planned too, with the puzzle's own clues placed:
        // filling the whole plan nearly fills the grid, which leaves nothing for Pointing to do.
        let wide = Set(Puzzle.Index.allIndices.filter { position in
            plan.contains(position) || Symmetry.rotational180.orbit(of: position).allSatisfy { plan.contains($0) == false }
        })
        let strict = PlanFiller.Request(plan: wide, clues: puzzle, recorded: [RecordedStep(technique: .lockedCandidatesPointing)])
        var generator = SearchRandom(seed: 9)
        #expect(PlanFiller.fill(strict, using: &generator, maxMoves: 200) == nil)

        var relaxed = strict
        relaxed.relaxing = .rotational180
        let filled = try #require(PlanFiller.fill(relaxed, using: &generator, maxMoves: 200))
        #expect(PlanFiller.accepts(filled, for: relaxed))
        #expect(Symmetry.rotational180.isSatisfied(by: filled))
    }

    @Test func aBudgetWithoutATimeoutStillStops() {
        #expect(PlanFiller.Budget(walks: 2, timeout: nil).movesPerWalk == 50_000)
        #expect(PlanFiller.Budget(walks: 2, timeout: .seconds(1)).movesPerWalk == .max)
    }

    @Test func aFullyPlacedPlanThatSkipsTheRecordStopsAtOnce() {
        let request = PlanFiller.Request(plan: plan, clues: puzzle, recorded: [RecordedStep(technique: .xWing)])
        var generator = SearchRandom(seed: 1)
        let start = ContinuousClock.now
        #expect(PlanFiller.fill(request, using: &generator, maxMoves: 100_000) == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func cluesOutsideThePlanFillNothing() {
        var clues = Solution.empty()
        let outside = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        clues[outside.row][outside.column] = solution[outside.row][outside.column]
        var generator = SearchRandom(seed: 1)
        #expect(PlanFiller.fill(PlanFiller.Request(plan: plan, clues: clues), using: &generator, maxMoves: 1_000) == nil)
    }

    @Test func racingWalksFindAFill() async throws {
        let request = PlanFiller.Request(plan: plan)
        let filled = try #require(await PlanFiller.fill(request, seed: 21, budget: PlanFiller.Budget(walks: 4, timeout: nil, movesPerWalk: 50_000)))
        #expect(PlanFiller.accepts(filled, for: request))
    }
}

extension PlanFillerTests {
    @Test func aWalkStartsFromANearbyFill() {
        var clues = Solution.empty()
        for position in plan.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }).prefix(10) {
            clues[position.row][position.column] = puzzle[position.row][position.column]
        }
        let request = PlanFiller.Request(plan: plan, clues: clues)
        var generator = SearchRandom(seed: 1)
        // Starting from the puzzle itself, the first state is already a fill.
        #expect(PlanFiller.fill(request, using: &generator, maxMoves: 1, near: puzzle) == puzzle)
    }
}

// MARK: - Suggesting squares

extension PlanFillerTests {
    @Test func aClosedPlanGetsSquaresInItsEmptyLines() async {
        let closed = Set(plan.filter { $0.row != 0 && $0.row != 1 })
        #expect(PlanFiller.swappableLines(in: closed).isEmpty == false)
        let suggestions = await PlanFiller.squaresToAdd(
            PlanFiller.Request(plan: closed), symmetry: .rotational180, seed: 1, budget: .moves(100)
        )
        #expect(suggestions.isEmpty == false)
        for orbit in suggestions {
            #expect(orbit.contains { $0.row == 0 || $0.row == 1 })
            #expect(orbit.allSatisfy { closed.contains($0) == false })
            #expect(Set(orbit) == Set(Symmetry.rotational180.orbit(of: orbit[0])))
        }
    }

    @Test func aFillablePlanNeedsNoSquares() async {
        let suggestions = await PlanFiller.squaresToAdd(
            PlanFiller.Request(plan: plan, clues: puzzle), symmetry: .rotational180, seed: 1, budget: .moves(100)
        )
        #expect(suggestions.isEmpty)
    }

    @Test func aSmallPlanGetsSquaresWhereItsNearestMissHasAChoice() async throws {
        // The puzzle's plan less four orbits: too few squares for one solution.
        let orbits = Symmetry.rotational180.orbits.filter { orbit in orbit.allSatisfy(plan.contains) }
        let small = plan.subtracting(orbits.prefix(4).flatMap { $0 })
        let request = PlanFiller.Request(plan: small)
        let near = try #require(await PlanFiller.nearestFill(request, seed: 2, budget: .moves(300)))
        try #require(near.solutionCount > 1)
        #expect(near.differing.isEmpty == false)
        let suggestions = await PlanFiller.squaresToAdd(request, symmetry: .rotational180, seed: 2, budget: .moves(300))
        #expect(suggestions.isEmpty == false)
        for orbit in suggestions {
            #expect(orbit.allSatisfy { small.contains($0) == false })
            #expect(orbit.contains(where: near.differing.contains))
        }
    }

    @Test func theNearestFillOfAFillablePlanIsAFill() async throws {
        let near = try #require(await PlanFiller.nearestFill(PlanFiller.Request(plan: plan, clues: puzzle), seed: 1, budget: .moves(10)))
        #expect(near.solutionCount == 1)
        #expect(near.grid == puzzle)
        #expect(near.differing.isEmpty)
    }
}
