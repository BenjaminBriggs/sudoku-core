//
//  HoDoKuCalculator.swift
//  SudokuCore
//
//  Estimates the score and level HoDoKu gives a puzzle.
//

import Foundation

/// HoDoKu's difficulty levels.
public enum HoDoKuLevel: String, Codable, Hashable, CaseIterable, Sendable, Comparable {
    case easy
    case medium
    case hard
    case unfair
    case extreme

    /// The highest score at this level, by HoDoKu 2.6's defaults.
    public var maxScore: Int {
        switch self {
        case .easy: 800
        case .medium: 1000
        case .hard: 1600
        case .unfair: 1800
        case .extreme: .max
        }
    }

    public static func < (a: HoDoKuLevel, b: HoDoKuLevel) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// Estimates the rating HoDoKu 2.6 gives a puzzle, so its difficulty can be compared with
/// HoDoKu's.
///
/// The hint finder solves the puzzle trying techniques in HoDoKu's order, and each step scores
/// HoDoKu's points for its technique. As in HoDoKu, the level is the higher of the score's
/// level and the level of the hardest step: one finned Swordfish makes a puzzle unfair,
/// whatever its score.
///
/// HoDoKu has techniques the hint finder doesn't, so its own path can differ. The HoDoKu
/// cross-check measures how close the estimate comes (see `scripts/hodoku/README.md`).
public enum HoDoKuCalculator {
    public struct Rating: Sendable, Equatable {
        public let score: Int
        public let level: HoDoKuLevel
        /// The points each technique adds.
        public let breakdown: [TechniqueID: Int]
    }

    /// The classic techniques in HoDoKu's solve order.
    public static let techniques: [any HintTechnique] = ClassicTechniques.all
        .filter { $0.info == .validation || RatingTables.HoDoKu.steps[$0.info.id] != nil }
        .sorted { (RatingTables.HoDoKu.steps[$0.info.id]?.order ?? 0) < (RatingTables.HoDoKu.steps[$1.info.id]?.order ?? 0) }

    /// HoDoKu's rating of `grid`, or nil when the hint finder can't solve it: HoDoKu would go
    /// on with chains and other techniques the hint finder doesn't have.
    public static func compute(for grid: [[Int]]) -> Rating? {
        let path = SolvePathEmitter.emit(from: grid) { state in
            techniques.lazy.compactMap { $0.findHint(in: state) }.first
        }
        guard path.solved else { return nil }
        var score = 0
        var level = HoDoKuLevel.easy
        var breakdown: [TechniqueID: Int] = [:]
        for step in path.steps {
            guard let hodoku = RatingTables.HoDoKu.steps[step.technique.id] else { continue }
            score += hodoku.points
            level = max(level, hodoku.level)
            breakdown[step.technique.id, default: 0] += hodoku.points
        }
        level = max(level, HoDoKuLevel.allCases.first { score <= $0.maxScore }!)
        return Rating(score: score, level: level, breakdown: breakdown)
    }
}
