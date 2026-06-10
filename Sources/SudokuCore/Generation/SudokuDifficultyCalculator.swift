//
//  SudokuDifficultyCalculator.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//

import Foundation

/// Calculates Sudoku difficulty by simulating human solving with available hint techniques
///
/// # HoDoKu Rating System
///
/// The calculator uses the HoDoKu cumulative effort rating system, which sums points
/// for each technique used during the solve process. This is a well-established standard
/// used by the Sudoku community.
///
/// ## Difficulty Ranges (HoDoKu Points)
/// - **Beginner (1-300)**: Primarily naked/hidden singles, basic techniques
/// - **Intermediate (301-600)**: Requires pairs, triples, pointing/claiming
/// - **Advanced (601-1000)**: Advanced techniques like X-Wing, Swordfish, Wings
/// - **Expert (1001-1600)**: Complex chains and advanced patterns
/// - **Master (1601-2000+)**: Extreme techniques and complex solving paths
///
/// ## Additional Ratings
/// The calculator also computes:
/// - **SE Rating**: Sudoku Explainer rating (hardest technique used)
/// - **Time Estimate**: Estimated completion time based on difficulty
///
/// ## Solving Process
/// The calculator simulates human solving by:
/// 1. Starting with an empty board and valid candidates
/// 2. Attempting techniques in order from easiest to hardest
/// 3. Applying the first applicable hint found
/// 4. Repeating until solved or no more hints available
/// 5. Recording all techniques used and computing HoDoKu/SE ratings
public enum SudokuDifficultyCalculator {
    enum DifficultyError: Error {
        case unsolved
    }

    /// Determines difficulty by solving the puzzle with progressively harder techniques
    /// - Returns: Difficulty information including level, score, and techniques used
    public static func calculateDifficulty(for initialGrid: [[Int]]) throws -> DifficultyResult {

        // Build a solve path once and derive metrics from it
        let path = SolvePathEmitter.emit(from: initialGrid)
        var techniquesUsed: [HintTechnique] = path.steps.map { $0.technique }
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
        // Compute SE / HoDoKu ratings and time estimate from the same path
        let se = SECalculator.compute(from: path)
        let hodoku = HoDoKuCalculator.compute(from: path)
        let timeEstimate = TimeEstimator.estimate(fromHoDoKu: hodoku.rating)

        return try calculateDifficultyMetrics(
            wasSolved: wasSolved,
            techniquesUsed: techniquesUsed,
            iterationCount: iterationCount,
            seRating: se.rating,
            hodokuRating: hodoku.rating,
            estimatedTimeSeconds: timeEstimate.personalizedSeconds ?? timeEstimate.baselineSeconds
        )
    }

    // Helpers moved to SolveUtilities.swift (BoardState.fromGrid, BoardState.isSolved, BoardState.applying, HintFinder.firstHint)

    /// Calculates difficulty metrics based on HoDoKu rating
    /// Uses the HoDoKu cumulative effort score to classify difficulty level
    private static func calculateDifficultyMetrics(
        wasSolved: Bool,
        techniquesUsed: [HintTechnique],
        iterationCount: Int,
        seRating: Double?,
        hodokuRating: Int?,
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

        // Use HoDoKu rating as the primary score
        // Default to a basic score if HoDoKu rating is not available
        let score = Double(hodokuRating ?? 1)

        // Determine difficulty level based on HoDoKu rating thresholds
        let level: PuzzleDifficulty.Level
        if score <= 300 {
            level = .easy
        } else if score <= 600 {
            level = .medium
        } else if score <= 1000 {
            level = .hard
        } else if score <= 1600 {
            level = .expert
        } else if score <= 2000 {
            level = .professional
        } else {
            level = .custom
        }

        return DifficultyResult(
            level: level,
            score: score,
            techniquesUsed: techniquesUsed,
            iterationCount: iterationCount,
            wasSolved: wasSolved,
            seRating: seRating,
            hodokuRating: hodokuRating,
            estimatedTimeSeconds: estimatedTimeSeconds
        )
    }

    /// Result of difficulty calculation
    public struct DifficultyResult: Sendable, Equatable {
        /// The calculated difficulty level
        public let level: PuzzleDifficulty.Level

        /// The difficulty score in HoDoKu points (see the class-level difficulty ranges)
        public let score: Double

        /// All techniques that were used to solve the puzzle
        public let techniquesUsed: [HintTechnique]

        /// Number of iterations needed to solve
        public let iterationCount: Int

        /// Whether the puzzle was successfully solved
        public let wasSolved: Bool

        /// Optional standard ratings and time
        public let seRating: Double?
        public let hodokuRating: Int?
        public let estimatedTimeSeconds: Int?

        /// The most advanced technique used (ignores `.unknown` fallback marker)
        public var hardestTechnique: HintTechnique? {
            let filtered = techniquesUsed.filter { $0 != .unknown }
            return filtered.max(by: { $0.difficulty < $1.difficulty })
        }

        /// Frequency of each technique used
        public var techniqueFrequency: [HintTechnique: Int] {
            var frequency: [HintTechnique: Int] = [:]
            for technique in techniquesUsed {
                frequency[technique, default: 0] += 1
            }
            return frequency
        }

        public init(
            level: PuzzleDifficulty.Level,
            score: Double,
            techniquesUsed: [HintTechnique],
            iterationCount: Int,
            wasSolved: Bool,
            seRating: Double? = nil,
            hodokuRating: Int? = nil,
            estimatedTimeSeconds: Int? = nil
        ) {
            self.level = level
            self.score = score
            self.techniquesUsed = techniquesUsed
            self.iterationCount = iterationCount
            self.wasSolved = wasSolved
            self.seRating = seRating
            self.hodokuRating = hodokuRating
            self.estimatedTimeSeconds = estimatedTimeSeconds
        }

        public var puzzleDifficulty: PuzzleDifficulty {
            let fallback: HintTechnique = {
                switch self.level {
                case .easy: return .hiddenSingle
                case .medium: return .lockedCandidatesPointing
                case .hard: return .xWing
                case .expert: return .swordfish
                case .professional: return .xyWing
                case .custom: return .hiddenSingle
                }
            }()
            return PuzzleDifficulty(
                level: self.level,
                hardestTechnique: self.hardestTechnique ?? fallback,
                score: Int(self.score),
                seRating: self.seRating,
                hodokuRating: self.hodokuRating,
                estimatedTimeSeconds: self.estimatedTimeSeconds
            )
        }
    }
}
