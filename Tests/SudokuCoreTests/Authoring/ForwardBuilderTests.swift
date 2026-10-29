//
//  ForwardBuilderTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct ForwardBuilderTests {
    /// Unique, 180° symmetric, solved by singles and Pointing.
    let puzzle: [[Int]] = Solution.cells(
        from: "020608000580009700000040000370000500600000004008000013000020000009800036000306090"
    )

    var plan: Set<Puzzle.Index> {
        Set(Puzzle.Index.allIndices.filter { puzzle[$0.row][$0.column] != 0 })
    }

    var orderedPlan: [Puzzle.Index] {
        plan.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    func clues(_ squares: some Sequence<Puzzle.Index>) -> [[Int]] {
        var clues = Solution.empty()
        for position in squares { clues[position.row][position.column] = puzzle[position.row][position.column] }
        return clues
    }

    func make(plan: Set<Puzzle.Index>, clues: [[Int]] = Solution.empty()) -> ForwardBuilder {
        guard let builder = ForwardBuilder(plan: plan, clues: clues) else { fatalError("Clues outside the plan or clashing") }
        return builder
    }

    // MARK: - State

    @Test func cluesOutsideThePlanOrClashingAreRefused() {
        let outside = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        var stray = Solution.empty()
        stray[outside.row][outside.column] = 1
        #expect(ForwardBuilder(plan: plan, clues: stray) == nil)
        var clash = clues(orderedPlan.prefix(1))
        let first = orderedPlan[0]
        let rowmate = try? #require(orderedPlan.first { $0 != first && $0.row == first.row })
        if let rowmate {
            clash[rowmate.row][rowmate.column] = clash[first.row][first.column]
            #expect(ForwardBuilder(plan: plan, clues: clash) == nil)
        }
    }

    @Test func anEmptyBuildHasEveryPlannedSquareOpen() {
        let builder = make(plan: plan)
        #expect(builder.openSquares.count == plan.count)
        #expect(builder.knownClues == Solution.empty())
        #expect(builder.witness == nil)
    }

    @Test func aFullyPlacedBuildIsSolvedByLogic() {
        let builder = make(plan: plan, clues: puzzle)
        #expect(builder.openSquares.isEmpty)
        #expect(ForwardBuilder.filled(builder.state) == 81)
    }

    @Test func planSquaresLogicFillsCountAsClues() throws {
        // The puzzle is minimal, so plan one square more: with the puzzle's clues placed, logic
        // fills it, and it shows as a clue without being placed.
        let extra = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        guard case .unique(let solution) = Validator.solutionCount(of: puzzle) else {
            Issue.record("Fixture isn't unique")
            return
        }
        let builder = make(plan: plan.union([extra]), clues: puzzle)
        #expect(builder.openSquares.isEmpty)
        #expect(builder.clues[extra.row][extra.column] == 0)
        #expect(builder.knownClues[extra.row][extra.column] == solution[extra.row][extra.column])
    }

    // MARK: - Options

    @Test func optionsAreOnlyForOpenPlannedSquares() {
        let builder = make(plan: plan, clues: clues(orderedPlan.prefix(5)))
        let outside = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        #expect(builder.options(at: outside).isEmpty)
        #expect(builder.options(at: orderedPlan[0]).isEmpty)
        let open = builder.openSquares[0]
        let values = builder.options(at: open).map(\.value)
        #expect(values.isEmpty == false)
        #expect(Set(values).count == values.count)
        #expect(values.allSatisfy { builder.state.pencilMarks[open.row][open.column].contains($0) })
    }

    @Test func anOptionReportsTheLogicItUnlocks() throws {
        // The puzzle less one clue: putting it back lets logic finish the grid.
        for removed in orderedPlan {
            let builder = make(plan: plan, clues: clues(plan.subtracting([removed])))
            guard builder.openSquares == [removed] else { continue }
            let option = try #require(builder.options(at: removed).first { $0.value == puzzle[removed.row][removed.column] })
            #expect(option.solvedSquares == 81 - ForwardBuilder.filled(builder.state) - 1)
            #expect(option.forcedPlanSquares == 0)
            return
        }
        Issue.record("Every clue was already forced by the others")
    }

    @Test func allOptionsCoverEveryOpenSquare() async {
        let builder = make(plan: plan, clues: clues(orderedPlan.prefix(12)))
        let options = await builder.options()
        #expect(Set(options.map(\.position)) == Set(builder.openSquares))
    }

    // MARK: - Witness

    @Test func findsAWitnessForAnEmptyPlan() async throws {
        let builder = try #require(await make(plan: plan).withWitness(seed: 1, budget: .moves(50_000)))
        let witness = try #require(builder.witness)
        #expect(PlanFiller.accepts(witness, for: builder.fillRequest))
    }

    @Test func aClosedPlanHasNoWitness() async {
        let closed = Set(Puzzle.Index.allIndices.filter { $0.row >= 2 })
        #expect(await make(plan: closed).withWitness(seed: 1, budget: .moves(2_000)) == nil)
    }

    @Test func quietCluesFromTheWitnessKeepIt() async throws {
        var builder = try #require(await make(plan: plan).withWitness(seed: 4, budget: .moves(50_000)))
        let witness = try #require(builder.witness)
        let solution = try #require(builder.witnessSolution)
        for _ in 0..<6 {
            guard let square = builder.openSquares.first else { break }
            let value = solution[square.row][square.column]
            let option = try #require(builder.options(at: square).first { $0.value == value })
            #expect(option.matchesWitness)
            builder = try #require(await builder.placing(value, at: square, seed: 0, budget: .moves(2_000)))
            #expect(builder.witness == witness)
        }
    }

    @Test func aClueAgainstTheWitnessFindsAnother() async throws {
        let builder = try #require(await make(plan: plan).withWitness(seed: 6, budget: .moves(50_000)))
        let solution = try #require(builder.witnessSolution)
        let square = builder.openSquares[0]
        let other = try #require(builder.options(at: square).first { $0.value != solution[square.row][square.column] })
        #expect(other.matchesWitness == false)
        let next = try #require(await builder.placing(other.value, at: square, seed: 7, budget: .moves(50_000)))
        let witness = try #require(next.witness)
        #expect(witness[square.row][square.column] == other.value)
        #expect(PlanFiller.accepts(witness, for: next.fillRequest))
    }

    @Test func recordingKeepsTheStepInTheWitness() async throws {
        // Remove one clue at a time until putting it back needs a technique beyond singles.
        for removed in orderedPlan {
            let builder = make(plan: plan, clues: clues(plan.subtracting([removed])))
            guard let option = builder.options(at: removed).first(where: {
                $0.value == puzzle[removed.row][removed.column] && $0.technique != nil
            }) else { continue }
            let recorded = try #require(await builder.recording(option, seed: 3, budget: .moves(50_000)))
            #expect(recorded.recorded == [option.technique!])
            let witness = try #require(recorded.witness)
            #expect(PlanFiller.accepts(witness, for: recorded.fillRequest))
            let path = SolvePathEmitter.emit(from: witness, using: ClassicTechniques.upTo(.hard))
            #expect(path.steps.contains { $0.technique == option.technique })
            return
        }
        Issue.record("No clue needed a technique beyond singles")
    }

    @Test func adoptingChecksTheWitness() throws {
        let builder = make(plan: plan)
        #expect(builder.adopting(puzzle)?.witness == puzzle)
        var outside = puzzle
        let square = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        guard case .unique(let solution) = Validator.solutionCount(of: puzzle) else { return }
        outside[square.row][square.column] = solution[square.row][square.column]
        #expect(builder.adopting(outside) == nil)
    }
}

extension ForwardBuilderTests {
    @Test func anOptionFromAnotherBuilderIsRefused() async throws {
        let before = make(plan: plan, clues: clues(orderedPlan.prefix(10)))
        let after = make(plan: plan, clues: clues(orderedPlan.prefix(11)))
        let square = try #require(before.openSquares.first { after.openSquares.contains($0) })
        let stale = try #require(before.options(at: square).first)
        #expect(await after.recording(stale, seed: 1, budget: .moves(100)) == nil)
    }
}

// MARK: - Option accessors

extension ForwardBuilderTests {
    /// The first option, from removing one clue at a time, whose putting back needs a technique
    /// beyond singles.
    func techniqueOption() -> (ForwardBuilder, ForwardBuilder.Option)? {
        for removed in orderedPlan {
            let builder = make(plan: plan, clues: clues(plan.subtracting([removed])))
            if let option = builder.options(at: removed).first(where: {
                $0.value == puzzle[removed.row][removed.column] && $0.technique != nil
            }) {
                return (builder, option)
            }
        }
        return nil
    }

    @Test func aTechniqueOptionExplainsItsStep() throws {
        let (_, option) = try #require(techniqueOption())
        let index = try #require(option.techniqueStepIndex)
        #expect(option.steps[index].technique == option.technique)
        let hint = try #require(option.techniqueHint)
        #expect(hint.technique == option.technique)
        #expect(hint.reasoning.components.isEmpty == false)
        #expect(hint.reasoning.inconsistencies(in: option.state(before: index)).isEmpty)
    }

    @Test func replayingTheStepsReachesTheOptionsState() throws {
        let (_, option) = try #require(techniqueOption())
        #expect(option.state(before: 0).grid == option.start.grid)
        let end = option.state(before: option.steps.count)
        #expect(end.grid == option.state.grid)
        #expect(end.pencilMarks == option.state.pencilMarks)
        #expect(option.start.grid[option.position.row][option.position.column] == option.value)
    }

    @Test func aSinglesOptionHasNoTechniqueStep() throws {
        let builder = make(plan: plan, clues: clues(orderedPlan.prefix(12)))
        let option = try #require(builder.openSquares.lazy.flatMap { builder.options(at: $0) }.first { $0.technique == nil })
        #expect(option.techniqueStepIndex == nil)
        #expect(option.techniqueHint == nil)
    }

    @Test func cancelledOptionsStopAtOnce() async {
        let builder = make(plan: plan, clues: clues(orderedPlan.prefix(8)))
        let options = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await builder.options()
        }.value
        #expect(options.isEmpty)
    }
}
