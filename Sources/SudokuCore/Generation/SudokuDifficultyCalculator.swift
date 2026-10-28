//
//  SudokuDifficultyCalculator.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//

import Foundation

/// Calculates Sudoku difficulty by simulating human solving with available hint techniques
///
/// # Level, difficulty and tedium
///
/// ``ScoreCalculator`` sums each step's ``TechniqueInfo/scorePoints`` (HoDoKu 2.6's step scores)
/// over the solve path and splits the sum in two:
/// - **difficulty**: the steps beyond singles, the skill the puzzle asks for
/// - **tedium**: the singles, 4 a naked and 14 a hidden one, the slog
///
/// The level is the hardest step's ``TechniqueInfo/level``, nothing else. Unlike HoDoKu, a long
/// path never promotes a puzzle: fifty singles are a tedious Beginner puzzle, and one W-Wing
/// after twenty singles is an Advanced one. Guessing is Master.
///
/// ## Additional Ratings
/// The calculator also computes:
/// - **SE Rating**: Sudoku Explainer rating (hardest technique used)
/// - **HoDoKu Rating**: ``HoDoKuCalculator``'s estimate of HoDoKu's own score and level
/// - **Time Estimate**: Estimated completion time based on difficulty
///
/// ## Solving Process
/// The calculator simulates human solving by:
/// 1. Starting with an empty board and valid candidates
/// 2. Attempting techniques in order from easiest to hardest
/// 3. Applying the first applicable hint found
/// 4. Repeating until solved or no more hints available
/// 5. Recording all techniques used and computing the score and ratings
public enum SudokuDifficultyCalculator {
    enum DifficultyError: Error {
        case unsolved
    }

    /// Determines difficulty by solving the puzzle with progressively harder techniques
    /// - Returns: Difficulty information including level, score, and techniques used
    public static func calculateDifficulty(for initialGrid: [[Int]]) throws -> DifficultyResult {
        try calculateDifficulty(for: initialGrid, estimatingHoDoKu: true)
    }

    /// ``calculateDifficulty(for:)``, leaving out the HoDoKu estimate when `estimatingHoDoKu` is
    /// false. The estimate solves the puzzle a second time, so the generator leaves it out of the
    /// many ratings it makes along the way.
    static func calculateDifficulty(for initialGrid: [[Int]], estimatingHoDoKu: Bool) throws -> DifficultyResult {

        // Build a solve path once and derive metrics from it
        let path = SolvePathEmitter.emit(from: initialGrid)
        var techniquesUsed: [TechniqueInfo] = path.steps.map { $0.technique }
        var iterationCount: Int = path.iterationCount
        var state = path.finalState
        var wasSolved: Bool = path.solved

        if !state.isSolved {
            let primaryResult = SudokuSolver.solve(grid: state.grid)
            let fallbackResult =
                primaryResult.solution != nil
                ? primaryResult : SudokuSolver.solve(grid: initialGrid)
            if let solution = fallbackResult.solution {
                let options = Validator.validOptions(for: solution)
                state = BoardState(
                    grid: solution,
                    pencilMarks: options,
                    validOptions: options
                )
                if techniquesUsed.contains(.unknown) == false {
                    techniquesUsed.append(.unknown)
                }
                iterationCount += max(0, fallbackResult.callCount)
            }
        }

        // Check if we solved the puzzle
        wasSolved = state.isSolved

        // Calculate difficulty metrics
        // Compute the score, SE rating and time estimate from the same path; the HoDoKu
        // estimate solves in HoDoKu's order.
        let se = SECalculator.compute(from: path)
        let score = ScoreCalculator.compute(from: path)
        let hodoku = estimatingHoDoKu ? HoDoKuCalculator.compute(for: initialGrid) : nil
        let timeEstimate = TimeEstimator.estimate(fromHoDoKu: score.score)

        return try calculateDifficultyMetrics(
            wasSolved: wasSolved,
            techniquesUsed: techniquesUsed,
            iterationCount: iterationCount,
            score: score,
            seRating: se.rating,
            hodoku: hodoku,
            estimatedTimeSeconds: timeEstimate.personalizedSeconds ?? timeEstimate.baselineSeconds
        )
    }

    // Helpers moved to SolveUtilities.swift (BoardState.fromGrid, BoardState.isSolved, BoardState.applying, HintFinder.firstHint)

    /// Calculates difficulty metrics; the level is the hardest step's
    private static func calculateDifficultyMetrics(
        wasSolved: Bool,
        techniquesUsed: [TechniqueInfo],
        iterationCount: Int,
        score: ScoreCalculator.Score,
        seRating: Double?,
        hodoku: HoDoKuCalculator.Rating?,
        estimatedTimeSeconds: Int?
    ) throws -> DifficultyResult {
        // If not solved, throw error
        guard wasSolved else {
            throw DifficultyError.unsolved
        }

        // Handle case where puzzle was already complete (no techniques needed)
        if techniquesUsed.isEmpty {
            return DifficultyResult(
                level: .easy,
                score: 1.0,
                techniquesUsed: [],
                iterationCount: iterationCount,
                wasSolved: true
            )
        }

        // The hardest step's level. The path's score doesn't count the guessing marker the
        // solver fallback appends, so the level is taken over every technique used.
        let level = techniquesUsed.map(\.level).max() ?? score.level

        return DifficultyResult(
            level: level,
            score: Double(score.score),
            techniquesUsed: techniquesUsed,
            iterationCount: iterationCount,
            wasSolved: wasSolved,
            seRating: seRating,
            hodokuRating: hodoku?.score,
            hodokuLevel: hodoku?.level,
            estimatedTimeSeconds: estimatedTimeSeconds
        )
    }

    /// Result of difficulty calculation
    public struct DifficultyResult: Sendable, Equatable {
        /// The calculated difficulty level
        public let level: PuzzleDifficulty.Level

        /// Points over every step, each its technique's ``TechniqueInfo/scorePoints``:
        /// `difficulty + tedium`
        public let score: Double

        /// Points over the steps beyond singles: the skill the puzzle asks for
        public var difficulty: Int { pathScore.difficulty }

        /// Points over the singles, 4 a naked and 14 a hidden one: the slog
        public var tedium: Int { pathScore.tedium }

        /// The score of the steps the hint finder took, without the guessing marker.
        private var pathScore: ScoreCalculator.Score {
            ScoreCalculator.compute(from: techniquesUsed.filter { $0 != .unknown })
        }

        /// All techniques that were used to solve the puzzle
        public let techniquesUsed: [TechniqueInfo]

        /// Number of iterations needed to solve
        public let iterationCount: Int

        /// Whether the puzzle was successfully solved
        public let wasSolved: Bool

        /// Optional standard ratings and time
        public let seRating: Double?
        /// ``HoDoKuCalculator``'s estimate of HoDoKu's score, nil when the hint finder can't
        /// solve the puzzle.
        public let hodokuRating: Int?
        /// ``HoDoKuCalculator``'s estimate of HoDoKu's level, nil when the hint finder can't
        /// solve the puzzle.
        public let hodokuLevel: HoDoKuLevel?
        public let estimatedTimeSeconds: Int?

        /// The most advanced technique used (ignores `.unknown` fallback marker)
        public var hardestTechnique: TechniqueInfo? {
            let filtered = techniquesUsed.filter { $0 != .unknown }
            return filtered.max(by: { $0.difficulty < $1.difficulty })
        }

        /// The solve path stalls and the solver has to guess (`.unknown` closes the techniques).
        ///
        /// The score then only counts the steps before the stall, but the level is Master:
        /// guessing is HoDoKu's give-up, beyond every rated technique.
        public var needsGuessing: Bool {
            techniquesUsed.contains(.unknown)
        }

        /// How many steps use `hardestTechnique`.
        public var hardestTechniqueCount: Int {
            guard let hardest = hardestTechnique else { return 0 }
            return techniquesUsed.filter { $0 == hardest }.count
        }

        /// The hardest technique used after the last step that uses `hardestTechnique`, or
        /// `nil` when that step is the last one. Shows whether the hardest step breaks the
        /// puzzle open (only singles follow) or leaves more work.
        public var hardestTechniqueAfterLastHardestStep: TechniqueInfo? {
            guard let hardest = hardestTechnique,
                let last = techniquesUsed.lastIndex(of: hardest)
            else { return nil }
            return techniquesUsed[(last + 1)...]
                .filter { $0 != .unknown }
                .max(by: { $0.difficulty < $1.difficulty })
        }

        /// Frequency of each technique used
        public var techniqueFrequency: [TechniqueInfo: Int] {
            var frequency: [TechniqueInfo: Int] = [:]
            for technique in techniquesUsed {
                frequency[technique, default: 0] += 1
            }
            return frequency
        }

        public init(
            level: PuzzleDifficulty.Level,
            score: Double,
            techniquesUsed: [TechniqueInfo],
            iterationCount: Int,
            wasSolved: Bool,
            seRating: Double? = nil,
            hodokuRating: Int? = nil,
            hodokuLevel: HoDoKuLevel? = nil,
            estimatedTimeSeconds: Int? = nil
        ) {
            self.level = level
            self.score = score
            self.techniquesUsed = techniquesUsed
            self.iterationCount = iterationCount
            self.wasSolved = wasSolved
            self.seRating = seRating
            self.hodokuRating = hodokuRating
            self.hodokuLevel = hodokuLevel
            self.estimatedTimeSeconds = estimatedTimeSeconds
        }

        public var puzzleDifficulty: PuzzleDifficulty {
            let fallback: TechniqueInfo = {
                switch self.level {
                case .easy: return .hiddenSingle
                case .medium: return .lockedCandidatesPointing
                case .hard: return .xWing
                case .expert: return .finnedSwordfish
                case .professional: return .unknown
                case .custom: return .hiddenSingle
                }
            }()
            return PuzzleDifficulty(
                level: self.level,
                hardestTechnique: (self.hardestTechnique ?? fallback).id,
                score: Int(self.score),
                difficulty: self.difficulty,
                tedium: self.tedium,
                seRating: self.seRating,
                hodokuRating: self.hodokuRating,
                hodokuLevel: self.hodokuLevel,
                estimatedTimeSeconds: self.estimatedTimeSeconds
            )
        }
    }
}
