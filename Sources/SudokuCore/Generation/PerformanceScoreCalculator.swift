//
//  PerformanceScoreCalculator.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//

import Foundation

/// Calculates player performance scores based on completion time, hints used, and errors made
///
/// # Performance Score (100-100,000)
///
/// The calculator produces a performance score from 100 to 100,000 based on:
/// - **Base Difficulty**: Puzzle's HoDoKu rating (1-2000+)
/// - **Time Multiplier**: How quickly the puzzle was solved relative to target time
/// - **Hint Penalty**: Reduction for each hint used
/// - **Error Penalty**: Progressive reduction for mistakes
/// - **Perfect Game Bonus**: Multiplier for flawless completion
///
/// ## Score Distribution
/// - **100-5,000**: Slow completion with multiple hints/errors
/// - **5,000-30,000**: Average completion with some assistance
/// - **30,000-70,000**: Good completion with minimal assistance
/// - **70,000-100,000**: Excellent to perfect completion
///
/// ## Target Times (for maximum time multiplier)
/// - **Easy (1-300)**: 3-8 minutes
/// - **Medium (301-600)**: 8-18 minutes
/// - **Hard (601-1000)**: 18-35 minutes
/// - **Expert (1001-1600)**: 35-55 minutes
/// - **Professional (1601-2000+)**: 55-90 minutes
///
/// ## Formula
/// ```
/// baseScore = baseDifficulty × timeMultiplier(elapsed, targetTime)
/// hintPenalty = 1 - (hintsUsed × hintPenaltyRate)
/// errorPenalty = 1 - (1 - exp(-0.8 × errorCount))
/// perfectionBonus = (hintsUsed == 0 && errorCount == 0 && underTargetTime) ? 2.5 : 1.0
/// finalScore = baseScore × hintPenalty × errorPenalty × perfectionBonus
/// normalizedScore = scale(finalScore, min: 100, max: 100000)
/// ```
///
/// ## Design Philosophy
/// - Rewards speed without sacrificing accuracy
/// - Progressive penalties that don't overly punish learning players
/// - Significant bonus for perfect completion to encourage mastery
/// - Scaled to provide meaningful progression across all difficulty levels
public enum PerformanceScoreCalculator {

    /// Result of performance score calculation
    public struct PerformanceResult: Sendable, Equatable {
        /// The final performance score (100-100,000)
        public let score: Int

        /// HoDoKu rating of the puzzle (1-2000+)
        public let baseDifficulty: Double

        /// Time multiplier applied (0.0-3.0)
        public let timeMultiplier: Double

        /// Hint penalty factor (0.0-1.0)
        public let hintPenalty: Double

        /// Error penalty factor (0.0-1.0)
        public let errorPenalty: Double

        /// No assistance bonus multiplier (1.0 when assistance used, 1.15 when no assistance)
        public let noAssistanceBonus: Double

        /// Whether the perfect game bonus was applied
        public let perfectBonus: Bool

        /// Time taken to complete the puzzle in seconds
        public let elapsedTime: TimeInterval

        /// Number of hints used
        public let hintsUsed: Int

        /// Number of errors made
        public let errorCount: Int

        /// Number of magic mode inputs used
        public let magicModeInputs: Int

        /// Number of note updates used
        public let noteUpdates: Int

        public init(
            score: Int,
            baseDifficulty: Double,
            timeMultiplier: Double,
            hintPenalty: Double,
            errorPenalty: Double,
            noAssistanceBonus: Double,
            perfectBonus: Bool,
            elapsedTime: TimeInterval,
            hintsUsed: Int,
            errorCount: Int,
            magicModeInputs: Int,
            noteUpdates: Int
        ) {
            self.score = score
            self.baseDifficulty = baseDifficulty
            self.timeMultiplier = timeMultiplier
            self.hintPenalty = hintPenalty
            self.errorPenalty = errorPenalty
            self.noAssistanceBonus = noAssistanceBonus
            self.perfectBonus = perfectBonus
            self.elapsedTime = elapsedTime
            self.hintsUsed = hintsUsed
            self.errorCount = errorCount
            self.magicModeInputs = magicModeInputs
            self.noteUpdates = noteUpdates
        }
    }

    /// Calculates performance score for a completed puzzle
    /// - Parameters:
    ///   - baseDifficulty: Puzzle's HoDoKu rating (1-2000+)
    ///   - elapsedTime: Time taken to complete in seconds
    ///   - hintsUsed: Number of hints used
    ///   - errorCount: Number of incorrect entries made
    ///   - magicModeInputs: Number of inputs made in magic mode (defaults to 0)
    ///   - noteUpdates: Number of times notes were updated (defaults to 0)
    /// - Returns: Performance result with score and breakdown
    public static func calculateScore(
        baseDifficulty: Int,
        elapsedTime: TimeInterval,
        hintsUsed: Int,
        errorCount: Int,
        magicModeInputs: Int = 0,
        noteUpdates: Int = 0
    ) -> PerformanceResult {
        // Clamp base difficulty to valid range
        let clampedDifficulty = Double(min(max(1, baseDifficulty), 2000))

        // Calculate time multiplier
        let timeMultiplier = calculateTimeMultiplier(
            difficulty: clampedDifficulty,
            elapsedTime: elapsedTime
        )

        // Calculate hint penalty (exponential curve, eases with difficulty)
        let hintPenalty = calculateHintPenalty(
            hintsUsed: hintsUsed,
            difficulty: clampedDifficulty
        )

        // Calculate error penalty (exponential growth)
        let errorPenalty = calculateErrorPenalty(errorCount: errorCount)

        // Calculate no assistance bonus (15% bonus for not using magic mode or note updates)
        let noAssistanceBonus = calculateNoAssistanceBonus(
            magicModeInputs: magicModeInputs,
            noteUpdates: noteUpdates
        )

        // Check for perfect game bonus
        let targetTime = calculateTargetTime(difficulty: clampedDifficulty)
        let perfectBonus = (hintsUsed == 0 && errorCount == 0 && elapsedTime <= targetTime)
        let bonusMultiplier = perfectBonus ? 2.5 : 1.0

        // Calculate raw score
        let baseScore = clampedDifficulty * timeMultiplier
        let penalizedScore = baseScore * hintPenalty * errorPenalty * noAssistanceBonus
        let finalScore = penalizedScore * bonusMultiplier

        // Scale to 100-100,000 range
        // Raw scores typically range from ~10 to ~3000 before scaling
        let scaledScore = scaleToRange(finalScore, min: 100, max: 100_000)

        return PerformanceResult(
            score: Int(scaledScore),
            baseDifficulty: clampedDifficulty,
            timeMultiplier: timeMultiplier,
            hintPenalty: hintPenalty,
            errorPenalty: errorPenalty,
            noAssistanceBonus: noAssistanceBonus,
            perfectBonus: perfectBonus,
            elapsedTime: elapsedTime,
            hintsUsed: hintsUsed,
            errorCount: errorCount,
            magicModeInputs: magicModeInputs,
            noteUpdates: noteUpdates
        )
    }

    // MARK: - Private Calculation Methods

    /// Calculates time multiplier based on how quickly the puzzle was solved
    /// Returns 0.3-3.0 multiplier based on performance relative to target time
    private static func calculateTimeMultiplier(
        difficulty: Double,
        elapsedTime: TimeInterval
    ) -> Double {
        let targetTime = calculateTargetTime(difficulty: difficulty)

        // If solved faster than target, reward with multiplier up to 3.0
        // If solved slower than target, reduce multiplier down to 0.3
        if elapsedTime <= targetTime {
            // Fast completion: 1.0 at target time, up to 3.0 for very fast
            // Formula: 1.0 + (2.0 * (1 - elapsed/target))
            let ratio = elapsedTime / targetTime
            return 1.0 + (2.0 * (1.0 - ratio))
        } else {
            // Slow completion: 1.0 at target time, down to 0.3 for very slow
            // Formula: 1.0 / (1 + (elapsed/target - 1))
            let ratio = elapsedTime / targetTime
            return Swift.max(0.3, 1.0 / (1.0 + (ratio - 1.0)))
        }
    }

    /// Calculates target completion time in seconds based on difficulty
    private static func calculateTargetTime(difficulty: Double) -> TimeInterval {
        switch difficulty {
        case 1...300:
            // Easy: 3-8 minutes, scaled linearly
            // At difficulty 1: 3 minutes (180s)
            // At difficulty 300: 8 minutes (480s)
            return 180.0 + ((difficulty - 1.0) / 299.0 * 300.0)

        case 301...600:
            // Medium: 8-18 minutes, scaled linearly
            // At difficulty 301: 8 minutes (480s)
            // At difficulty 600: 18 minutes (1080s)
            return 480.0 + ((difficulty - 301.0) / 299.0 * 600.0)

        case 601...1000:
            // Hard: 18-35 minutes, scaled linearly
            // At difficulty 601: 18 minutes (1080s)
            // At difficulty 1000: 35 minutes (2100s)
            return 1080.0 + ((difficulty - 601.0) / 399.0 * 1020.0)

        case 1001...1600:
            // Expert: 35-55 minutes, scaled linearly
            // At difficulty 1001: 35 minutes (2100s)
            // At difficulty 1600: 55 minutes (3300s)
            return 2100.0 + ((difficulty - 1001.0) / 599.0 * 1200.0)

        case 1601...:
            // Professional: 55-90 minutes, scaled linearly
            // At difficulty 1601: 55 minutes (3300s)
            // At difficulty 2000: 90 minutes (5400s)
            return 3300.0 + ((difficulty - 1601.0) / 399.0 * 2100.0)

        default:
            // Fallback for out-of-range values
            return 600.0
        }
    }

    /// Calculates hint penalty coefficient based on difficulty
    /// Harder puzzles are more forgiving of hint usage
    private static func calculateHintPenaltyCoefficient(difficulty: Double) -> Double {
        switch difficulty {
        case 1...300:
            // Easy: Steep penalty curve
            return 0.30

        case 301...600:
            // Medium: Moderate penalty curve
            return 0.22

        case 601...1000:
            // Hard: Gentler penalty curve
            return 0.16

        case 1001...1600:
            // Expert: More forgiving
            return 0.12

        case 1601...:
            // Professional: Most forgiving
            return 0.08

        default:
            return 0.22
        }
    }

    /// Calculates hint penalty factor (0.0-1.0)
    /// Uses exponential decay with difficulty-based coefficient
    private static func calculateHintPenalty(hintsUsed: Int, difficulty: Double) -> Double {
        if hintsUsed == 0 {
            return 1.0
        }

        let coefficient = calculateHintPenaltyCoefficient(difficulty: difficulty)

        // Exponential penalty formula: 1 - (1 - e^(-coefficient × count))
        // Easy (0.30): 1 hint ~26%, 3 hints ~59%, 5 hints ~78%
        // Medium (0.22): 1 hint ~20%, 3 hints ~48%, 5 hints ~67%
        // Hard (0.16): 1 hint ~15%, 3 hints ~38%, 5 hints ~55%
        // Expert (0.12): 1 hint ~11%, 3 hints ~30%, 5 hints ~45%
        // Professional (0.08): 1 hint ~8%, 3 hints ~21%, 5 hints ~33%
        let penalty = 1.0 - exp(-coefficient * Double(hintsUsed))
        return Swift.max(0.0, 1.0 - penalty)
    }

    /// Calculates error penalty factor (0.0-1.0)
    /// Uses exponential decay to progressively penalize errors
    private static func calculateErrorPenalty(errorCount: Int) -> Double {
        if errorCount == 0 {
            return 1.0
        }

        // Exponential penalty formula: 1 - (1 - e^(-0.28 × count))
        // Results:
        // 0 errors: 1.0 (no penalty)
        // 1 error: ~0.76 (24% penalty)
        // 2 errors: ~0.57 (43% penalty)
        // 3 errors: ~0.43 (57% penalty)
        // 5 errors: ~0.25 (75% penalty)
        // 10 errors: ~0.06 (94% penalty)
        let penalty = 1.0 - exp(-0.28 * Double(errorCount))
        return Swift.max(0.0, 1.0 - penalty)
    }

    /// Calculates no assistance bonus multiplier
    /// Rewards players who don't use magic mode or note updates with a 15% bonus
    private static func calculateNoAssistanceBonus(
        magicModeInputs: Int,
        noteUpdates: Int
    ) -> Double {
        // If neither assistance feature was used, award a 15% bonus
        if magicModeInputs == 0 && noteUpdates == 0 {
            return 1.15
        }

        // If either was used, no bonus (1.0 = neutral)
        return 1.0
    }

    /// Scales a raw score to the target range (100-100,000)
    private static func scaleToRange(_ value: Double, min minValue: Double, max maxValue: Double)
        -> Double
    {
        // Expected raw score ranges before scaling:
        // - Minimum: ~10 (slow easy puzzle with many hints/errors)
        // - Maximum: ~15,353 (reserves 100k for truly impossible performance)
        //
        // Score cap set so that realistic excellent performance (2k puzzle in 20 min)
        // achieves ~97,500, leaving room for superhuman scores to approach 100k.

        // Use logarithmic scaling to spread scores more evenly
        let logValue = Foundation.log10(Swift.max(1.0, value))
        let logMin = Foundation.log10(10.0)  // log10(10) ≈ 1.0
        let logMax = Foundation.log10(15353.0)  // log10(15353) ≈ 4.186

        // Normalize to 0-1 range
        let normalized = (logValue - logMin) / (logMax - logMin)
        let clamped = Swift.max(0.0, Swift.min(1.0, normalized))

        // Scale to target range
        return minValue + (clamped * (maxValue - minValue))
    }
}
