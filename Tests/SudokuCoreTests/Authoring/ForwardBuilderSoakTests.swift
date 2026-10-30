//
//  ForwardBuilderSoakTests.swift
//  SudokuCore
//
//  Opt-in: how often a setter's technique steps can be kept, matching each by its deduction
//  versus by its technique alone. Set `SUDOKU_FORWARD_SOAK` to a number of plans and
//  `SUDOKU_FORWARD_SOAK_REPORT` to a file for the results; run in release:
//
//      SUDOKU_FORWARD_SOAK=40 SUDOKU_FORWARD_SOAK_REPORT=/tmp/soak.txt \
//          swift test -c release --filter ForwardBuilderSoak
//
//  Each plan is a seeded 180° layout of 24, 26 or 28 squares. A greedy setter places quiet
//  clues from the witness until 40% of the plan is placed, then takes the least exposed
//  technique step that places a digit and keeps a witness, up to six, falling back to a
//  quiet clue.
//
import Foundation
import Testing
@testable import SudokuCore

struct ForwardBuilderSoakTests {
    static let plans = Int(ProcessInfo.processInfo.environment["SUDOKU_FORWARD_SOAK"] ?? "") ?? 0

    struct Tally {
        var builds = 0
        var recorded = 0
        var attempts = 0
        var kept = 0
        var keptSeconds: [Double] = []
        var attemptSeconds: [Double] = []

        func line(_ name: String) -> String {
            func percentile(_ values: [Double], _ p: Double) -> Double {
                guard values.isEmpty == false else { return 0 }
                let sorted = values.sorted()
                return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
            }
            return String(
                format: "%@: %d builds, %.2f steps kept per build, %d/%d attempts kept (%.0f%%), kept p50 %.2f s p90 %.2f s, any attempt p50 %.2f s p90 %.2f s",
                name, builds, Double(recorded) / Double(max(builds, 1)), kept, attempts,
                100 * Double(kept) / Double(max(attempts, 1)),
                percentile(keptSeconds, 0.5), percentile(keptSeconds, 0.9),
                percentile(attemptSeconds, 0.5), percentile(attemptSeconds, 0.9)
            )
        }
    }

    @Test(.enabled(if: plans > 0))
    func keepingStepsByDeductionAgainstByTechnique() async throws {
        var tallies: [RecordedStep.Matching: Tally] = [.deduction: Tally(), .technique: Tally()]
        var closedOrUnfilled = 0

        for index in 0..<Self.plans {
            var generator = SearchRandom(seed: UInt64(index) &* 7919 &+ 17)
            let plan = Self.layout(squares: [24, 26, 28][index % 3], using: &generator)
            guard let empty = ForwardBuilder(plan: plan),
                  let start = await empty.withWitness(seed: UInt64(index), budget: .moves(50_000)),
                  let witness = start.witness else {
                closedOrUnfilled += 1
                continue
            }
            for matching in [RecordedStep.Matching.deduction, .technique] {
                let configuration = ForwardBuilder.Configuration(matching: matching)
                guard var builder = ForwardBuilder(plan: plan, configuration: configuration)?.adopting(witness) else { continue }
                var tally = tallies[matching]!
                var seed = UInt64(index) &* 1_000
                while builder.openSquares.isEmpty == false, builder.recorded.count < 6 {
                    seed &+= 1
                    let placed = Double(plan.count - builder.openSquares.count) / Double(plan.count)
                    var moved = false
                    if placed >= 0.4 {
                        let offered = await builder.options()
                            .filter { $0.technique != nil && $0.solvedSquares > 0 }
                            .sorted { $0.exposure < $1.exposure }
                        for option in offered.prefix(8) {
                            let clock = ContinuousClock.now
                            let next = await builder.recording(option, seed: seed, budget: .moves(20_000))
                            let seconds = Self.seconds(ContinuousClock.now - clock)
                            tally.attempts += 1
                            tally.attemptSeconds.append(seconds)
                            if let next {
                                tally.kept += 1
                                tally.keptSeconds.append(seconds)
                                builder = next
                                moved = true
                                break
                            }
                        }
                    }
                    if moved == false {
                        guard let quiet = Self.quietClue(in: builder),
                              let next = await builder.placing(quiet.value, at: quiet.position, seed: seed, budget: .moves(20_000))
                        else { break }
                        builder = next
                    }
                }
                let finished = try #require(builder.witness)
                #expect(PlanFiller.accepts(finished, for: builder.fillRequest))
                tally.builds += 1
                tally.recorded += builder.recorded.count
                tallies[matching] = tally
            }
        }

        let report = [
            "Forward builder soak: \(Self.plans) plans, \(closedOrUnfilled) closed or without a first witness",
            tallies[.deduction]!.line("deduction"),
            tallies[.technique]!.line("technique"),
        ].joined(separator: "\n")
        if let path = ProcessInfo.processInfo.environment["SUDOKU_FORWARD_SOAK_REPORT"] {
            try report.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    /// A seeded 180° layout: whole orbits until it has `squares` squares.
    static func layout(squares: Int, using generator: inout SearchRandom) -> Set<Puzzle.Index> {
        var plan = Set<Puzzle.Index>()
        for orbit in Symmetry.rotational180.orbits.shuffled(using: &generator) where plan.count < squares {
            if plan.count + orbit.count <= squares { orbit.forEach { plan.insert($0) } }
        }
        return plan
    }

    /// The open square where the witness's digit gives logic the least, among the first few.
    static func quietClue(in builder: ForwardBuilder) -> (position: Puzzle.Index, value: Int)? {
        guard let solution = builder.witnessSolution else { return nil }
        let candidates = builder.openSquares.prefix(6).compactMap { square in
            builder.options(at: square).first { $0.value == solution[square.row][square.column] }
        }
        guard let best = candidates.min(by: { ($0.solvedSquares + 3 * $0.forcedPlanSquares) < ($1.solvedSquares + 3 * $1.forcedPlanSquares) })
        else { return nil }
        return (best.position, best.value)
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
