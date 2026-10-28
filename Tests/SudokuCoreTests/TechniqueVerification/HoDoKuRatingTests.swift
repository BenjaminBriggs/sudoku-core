//
//  HoDoKuRatingTests.swift
//  SudokuCore
//
//  Checks HoDoKuCalculator's estimates against the ratings HoDoKu itself gives. The estimate
//  solves with the hint finder, which doesn't have all of HoDoKu's techniques (chains, Sue de
//  Coq, Hidden Rectangles, Unique Rectangle type 6, Remote Pairs), so it can't match every
//  puzzle; these tests hold it to how closely it matched when they were written. Without
//  HoDoKu, each commit compares with HoDoKu's ratings recorded in Fixtures/hodoku-ratings.json.
//
import Foundation
import Synchronization
import Testing
@testable import SudokuCore

/// HoDoKu's ratings of 150 shipped puzzles the hint finder solves, the first 30 by id of each
/// level. `SUDOKU_UPDATE_HODOKU_FIXTURE=1` with `SUDOKU_HODOKU_JAR` rewrites the ratings.
struct HoDoKuRatingFixture: Codable {
    struct Recorded: Codable, Sendable {
        let grid: String
        let score: Int
        let level: HoDoKuLevel

        var rows: [[Int]] {
            let digits = grid.compactMap(\.wholeNumberValue)
            return (0..<9).map { Array(digits[($0 * 9)..<($0 * 9 + 9)]) }
        }
    }

    /// The HoDoKu release the ratings came from.
    let hodoku: String
    let puzzles: [Recorded]

    static let fileURL = HoDoKu.repository.appendingPathComponent("Tests/SudokuCoreTests/Fixtures/hodoku-ratings.json")

    static let recorded: [Recorded] = {
        guard let url = Bundle.module.url(forResource: "hodoku-ratings", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url),
              let fixture = try? JSONDecoder().decode(HoDoKuRatingFixture.self, from: data)
        else { return [] }
        return fixture.puzzles
    }()
}

/// How closely the estimates follow HoDoKu's ratings over a set of puzzles.
struct RatingAgreement: CustomStringConvertible {
    let count: Int
    let sameLevel: Int
    let withinOneLevel: Int
    /// The median of |estimate − HoDoKu| / HoDoKu.
    let medianError: Double
    /// (Σ estimates − Σ HoDoKu) / Σ HoDoKu: whether the estimates run high or low.
    let bias: Double

    init(_ pairs: [(estimate: HoDoKuCalculator.Rating, hodoku: (score: Int, level: HoDoKuLevel))]) {
        let levels = HoDoKuLevel.allCases
        count = pairs.count
        sameLevel = pairs.filter { $0.estimate.level == $0.hodoku.level }.count
        withinOneLevel = pairs.filter {
            abs(levels.firstIndex(of: $0.estimate.level)! - levels.firstIndex(of: $0.hodoku.level)!) <= 1
        }.count
        let errors = pairs.map { Double(abs($0.estimate.score - $0.hodoku.score)) / Double(max($0.hodoku.score, 1)) }.sorted()
        medianError = errors.isEmpty ? 0 : errors[errors.count / 2]
        let hodokuTotal = pairs.reduce(0) { $0 + $1.hodoku.score }
        bias = Double(pairs.reduce(0) { $0 + $1.estimate.score } - hodokuTotal) / Double(max(hodokuTotal, 1))
    }

    /// When written, the estimate gave HoDoKu's level for 139 of the 150 recorded puzzles and 27
    /// of the 33 corpus puzzles the hint finder solves (and 96% of all 3,745 shipped puzzles it
    /// solves), a level within one for all but one, a median score error of 2% and a bias of +2%.
    var isClose: Bool {
        let count = Double(count)
        return count > 0 && Double(sameLevel) >= 0.85 * count && Double(withinOneLevel) >= 0.98 * count
            && medianError <= 0.10 && abs(bias) <= 0.10
    }

    var description: String {
        "\(count) puzzles: \(sameLevel) at HoDoKu's level, \(withinOneLevel) within one, "
            + "median score error \(Int((medianError * 100).rounded()))%, bias \(Int((bias * 100).rounded()))%"
    }
}

struct HoDoKuRatingTests {
    @Test("The HoDoKu estimate follows HoDoKu's recorded ratings")
    func recorded() throws {
        let puzzles = HoDoKuRatingFixture.recorded
        try #require(puzzles.isEmpty == false)
        let estimates = Self.estimates(for: puzzles.map(\.rows))
        #expect(estimates.allSatisfy { $0 != nil }, "the hint finder no longer solves every recorded puzzle")
        let agreement = RatingAgreement(zip(estimates, puzzles).compactMap { estimate, recorded in
            estimate.map { ($0, (recorded.score, recorded.level)) }
        })
        #expect(agreement.isClose, "\(agreement)")
    }

    @Test("The HoDoKu estimate follows HoDoKu's own ratings", .enabled(if: HoDoKu.isAvailable))
    func live() throws {
        let recorded = HoDoKuRatingFixture.recorded
        let grids = recorded.map { (key: $0.grid, grid: $0.rows) }
            + CorpusPuzzle.all.map { (key: $0.id, grid: $0.startingState) }
        let ratings = try HoDoKu.ratings(for: grids)
        let estimates = Self.estimates(for: grids.map(\.grid))
        let pairs = zip(grids, estimates).compactMap { puzzle, estimate in
            estimate.flatMap { estimate in (ratings[puzzle.key] ?? nil).map { (estimate, $0) } }
        }
        let agreement = RatingAgreement(pairs)
        #expect(agreement.isClose, "\(agreement)")

        if ProcessInfo.processInfo.environment["SUDOKU_UPDATE_HODOKU_FIXTURE"] != nil {
            let puzzles = try recorded.map { puzzle in
                let rating = try #require(ratings[puzzle.grid] ?? nil, "HoDoKu doesn't solve \(puzzle.grid)")
                return HoDoKuRatingFixture.Recorded(grid: puzzle.grid, score: rating.score, level: rating.level)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let name = ProcessInfo.processInfo.environment["SUDOKU_HODOKU_VERSION"] ?? URL(fileURLWithPath: HoDoKu.jar!).lastPathComponent
            try encoder.encode(HoDoKuRatingFixture(hodoku: name, puzzles: puzzles)).write(to: HoDoKuRatingFixture.fileURL)
        } else {
            for puzzle in recorded {
                let rating = ratings[puzzle.grid] ?? nil
                #expect(rating?.score == puzzle.score && rating?.level == puzzle.level,
                        "HoDoKu now rates \(puzzle.grid) \(rating.map { "\($0.score) \($0.level)" } ?? "unsolved")")
            }
        }
    }

    /// The estimate for each grid, worked out in parallel.
    static func estimates(for grids: [[[Int]]]) -> [HoDoKuCalculator.Rating?] {
        let out = Mutex<[HoDoKuCalculator.Rating?]>(Array(repeating: nil, count: grids.count))
        DispatchQueue.concurrentPerform(iterations: grids.count) { i in
            let rating = HoDoKuCalculator.compute(for: grids[i])
            out.withLock { $0[i] = rating }
        }
        return out.withLock { $0 }
    }
}
