//
//  ForwardBuilderEditingTests.swift
//  SudokuCore
//
import Foundation
import Testing
@testable import SudokuCore

struct ForwardBuilderEditingTests {
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

    /// A build with ten clues placed and the puzzle as its witness.
    func build() throws -> ForwardBuilder {
        let builder = try #require(ForwardBuilder(plan: plan, clues: clues(orderedPlan.prefix(10))))
        return try #require(builder.adopting(puzzle))
    }

    // MARK: - Snapshots

    @Test func aSnapshotRoundTrips() throws {
        let builder = try build()
        let data = try JSONEncoder().encode(builder.snapshot)
        let restored = try #require(ForwardBuilder(restoring: try JSONDecoder().decode(ForwardBuilder.Snapshot.self, from: data)))
        #expect(restored.plan == builder.plan)
        #expect(restored.clues == builder.clues)
        #expect(restored.recorded == builder.recorded)
        #expect(restored.witness == puzzle)
        #expect(restored.configuration == builder.configuration)
        #expect(restored.state.grid == builder.state.grid)
    }

    @Test func aTamperedWitnessIsDropped() throws {
        var snapshot = try build().snapshot
        var witness = try #require(snapshot.witness)
        let square = orderedPlan.last!
        witness[square.row][square.column] = witness[square.row][square.column] % 9 + 1
        snapshot.witness = witness
        let restored = try #require(ForwardBuilder(restoring: snapshot))
        #expect(restored.witness == nil)
    }

    @Test func aNewerSnapshotDoesntRestore() throws {
        var snapshot = try build().snapshot
        snapshot.version = ForwardBuilder.Snapshot.currentVersion + 1
        #expect(ForwardBuilder(restoring: snapshot) == nil)
    }

    @Test func recordedStepsSurviveASnapshot() async throws {
        for removed in orderedPlan {
            let builder = try #require(ForwardBuilder(plan: plan, clues: clues(plan.subtracting([removed]))))
            guard let option = builder.options(at: removed).first(where: {
                $0.value == puzzle[removed.row][removed.column] && $0.technique != nil
            }), let recorded = await builder.recording(option, seed: 3, budget: .moves(50_000)) else { continue }
            let restored = try #require(ForwardBuilder(restoring: recorded.snapshot))
            #expect(restored.recorded == recorded.recorded)
            #expect(restored.witness == recorded.witness)
            return
        }
        Issue.record("No step could be recorded")
    }

    // MARK: - Editing the plan

    @Test func aPlanThatLeavesOutAPlacedClueIsRefused() throws {
        let builder = try build()
        #expect(builder.replacingPlan(plan.subtracting([orderedPlan[0]])) == nil)
    }

    @Test func aShrunkPlanKeepsTheWitnessWhenItStillFits() throws {
        // Plan one square more than the puzzle, with the puzzle as the witness: it leaves the
        // extra square empty. Taking that square out keeps the witness.
        let extra = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        let wide = try #require(ForwardBuilder(plan: plan.union([extra]), clues: clues(orderedPlan.prefix(10)))?.adopting(puzzle))
        #expect(wide.droppedSquares == [extra])
        let narrowed = try #require(wide.replacingPlan(plan))
        #expect(narrowed.witness == puzzle)
        #expect(narrowed.droppedSquares.isEmpty)
    }

    @Test func aShrunkPlanDropsAWitnessThatNoLongerFits() throws {
        // Taking out an unplaced square the witness needs leaves several solutions.
        let builder = try build()
        let unplaced = try #require(orderedPlan.dropFirst(10).first)
        let narrowed = try #require(builder.replacingPlan(plan.subtracting([unplaced])))
        #expect(narrowed.witness == nil)
    }

    @Test func aGrownPlanNeedsANewWitness() throws {
        let builder = try build()
        let extra = Puzzle.Index.allIndices.first { plan.contains($0) == false }!
        let grown = try #require(builder.replacingPlan(plan.union([extra])))
        #expect(grown.witness == nil)
        #expect(grown.plan.contains(extra))
    }

    // MARK: - Another ending

    @Test func anotherEndingIsADifferentFinish() async throws {
        let builder = try build()
        let other = try #require(await builder.withNewWitness(seed: 5, budget: .moves(50_000)))
        let witness = try #require(other.witness)
        #expect(witness != puzzle)
        #expect(PlanFiller.accepts(witness, for: other.fillRequest))
        #expect(other.clues == builder.clues)
    }
}
