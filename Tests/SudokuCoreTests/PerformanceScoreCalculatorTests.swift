//
//  PerformanceScoreCalculatorTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 05/03/2025.
//

import Foundation
import Testing

@testable import SudokuCore

struct PerformanceScoreCalculatorTests {

    // MARK: - Score Range Tests

    @Test("Performance scores are within valid range 100-100,000")
    func testScoreRange() {
        // Test various scenarios to ensure scores are always in valid range
        let scenarios: [(difficulty: Int, time: TimeInterval, hints: Int, errors: Int)] = [
            (difficulty: 1, time: 3600, hints: 10, errors: 10),  // Worst case easy
            (difficulty: 150, time: 300, hints: 0, errors: 0),  // Perfect easy
            (difficulty: 450, time: 900, hints: 5, errors: 3),  // Average medium
            (difficulty: 800, time: 1200, hints: 0, errors: 0),  // Perfect hard
            (difficulty: 1000, time: 300, hints: 0, errors: 0),  // Best possible
            (difficulty: 2000, time: 30, hints: 0, errors: 0),  // Impossibly fast
        ]

        for scenario in scenarios {
            let result = PerformanceScoreCalculator.calculateScore(
                baseDifficulty: scenario.difficulty,
                elapsedTime: scenario.time,
                hintsUsed: scenario.hints,
                errorCount: scenario.errors,
                magicModeInputs: 0,
                noteUpdates: 0,
            )

            #expect(
                result.score >= 100 && result.score <= 100_000,
                "Score \(String(describing: result.score)) should be in range 100-100,000 for difficulty \(String(describing: scenario.difficulty))"
            )
        }
    }

    // MARK: - Time Multiplier Tests

    @Test("Fast completion increases score")
    func testFastCompletionBonus() {
        let baseDifficulty = 150  // Easy puzzle

        // Solve in half the target time
        let fastResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 180,  // 3 minutes (target is ~4-5 min for difficulty 150)
            hintsUsed: 0,
            errorCount: 0
        )

        // Solve at target time
        let targetResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 300,  // 5 minutes
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            fastResult.score > targetResult.score,
            "Fast completion score (\(fastResult.score)) should exceed target time score (\(targetResult.score))"
        )
        #expect(
            fastResult.timeMultiplier > targetResult.timeMultiplier,
            "Fast time multiplier (\(fastResult.timeMultiplier)) should exceed target multiplier (\(targetResult.timeMultiplier))"
        )
    }

    @Test("Slow completion decreases score")
    func testSlowCompletionPenalty() {
        let baseDifficulty = 150  // Easy puzzle

        // Solve at target time
        let targetResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 300,  // 5 minutes
            hintsUsed: 0,
            errorCount: 0
        )

        // Solve much slower
        let slowResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 900,  // 15 minutes
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            slowResult.score < targetResult.score,
            "Slow completion score (\(slowResult.score)) should be less than target time score (\(targetResult.score))"
        )
        #expect(
            slowResult.timeMultiplier < targetResult.timeMultiplier,
            "Slow time multiplier (\(slowResult.timeMultiplier)) should be less than target multiplier (\(targetResult.timeMultiplier))"
        )
    }

    @Test("Time multiplier scales appropriately across difficulties")
    func testTimeMultiplierScaling() {
        let testTime = 600.0  // 10 minutes

        let easyResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 150,  // Easy
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let mediumResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,  // Medium
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let hardResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 800,  // Hard
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0
        )

        // 10 minutes should be good for easy, okay for medium, excellent for hard
        #expect(
            hardResult.timeMultiplier > mediumResult.timeMultiplier,
            "Hard puzzle time multiplier (\(hardResult.timeMultiplier)) should exceed medium (\(mediumResult.timeMultiplier)) for same time"
        )
        #expect(
            mediumResult.timeMultiplier > easyResult.timeMultiplier,
            "Medium puzzle time multiplier (\(mediumResult.timeMultiplier)) should exceed easy (\(easyResult.timeMultiplier)) for same time"
        )
    }

    // MARK: - Hint Penalty Tests

    @Test("Hints reduce score progressively")
    func testHintPenalty() {
        let baseDifficulty = 450  // Medium puzzle
        let testTime = 600.0

        let noHints = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let oneHint = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 1,
            errorCount: 0
        )

        let threeHints = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 3,
            errorCount: 0
        )

        #expect(
            oneHint.score < noHints.score,
            "One hint score (\(oneHint.score)) should be less than no hints (\(noHints.score))"
        )
        #expect(
            threeHints.score < oneHint.score,
            "Three hints score (\(threeHints.score)) should be less than one hint (\(oneHint.score))"
        )
        #expect(
            oneHint.hintPenalty < noHints.hintPenalty,
            "Hint penalty should increase with more hints"
        )
    }

    @Test("Hint penalty varies by difficulty")
    func testHintPenaltyByDifficulty() {
        let testTime = 600.0
        let hintsUsed = 2

        let easyResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 150,  // Easy (15% penalty per hint)
            elapsedTime: testTime,
            hintsUsed: hintsUsed,
            errorCount: 0
        )

        let mediumResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,  // Medium (10% penalty per hint)
            elapsedTime: testTime,
            hintsUsed: hintsUsed,
            errorCount: 0
        )

        let hardResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 800,  // Hard (7% penalty per hint)
            elapsedTime: testTime,
            hintsUsed: hintsUsed,
            errorCount: 0
        )

        // Hard puzzles are more forgiving of hints (higher penalty value = less penalty)
        #expect(
            hardResult.hintPenalty > mediumResult.hintPenalty,
            "Hard puzzle hint penalty (\(hardResult.hintPenalty)) should be more forgiving than medium (\(mediumResult.hintPenalty))"
        )
        #expect(
            mediumResult.hintPenalty > easyResult.hintPenalty,
            "Medium puzzle hint penalty (\(mediumResult.hintPenalty)) should be more forgiving than easy (\(easyResult.hintPenalty))"
        )
    }

    // MARK: - Magic Mode Penalty Tests

    @Test("Magic mode inputs reduce score with small penalty")
    func testMagicModePenalty() {
        let baseDifficulty = 450
        let testTime = 600.0

        let noMagic = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 0
        )

        let someMagic = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 20,
            noteUpdates: 0
        )

        let lotsOfMagic = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 50,
            noteUpdates: 0
        )

        #expect(
            noMagic.score > someMagic.score,
            "Not using magic mode should give bonus (got \(noMagic.score) vs \(someMagic.score))"
        )
        #expect(
            someMagic.score == lotsOfMagic.score,
            "Amount of magic mode usage shouldn't matter, only whether it was used (got \(someMagic.score) vs \(lotsOfMagic.score))"
        )
        #expect(
            noMagic.noAssistanceBonus == 1.15,
            "No assistance should give 15% bonus"
        )
        #expect(
            someMagic.noAssistanceBonus == 1.0,
            "Using magic mode should give no bonus"
        )
        #expect(
            lotsOfMagic.noAssistanceBonus == 1.0,
            "Using lots of magic mode should give no bonus"
        )
    }

    @Test("Magic mode penalty is small compared to other penalties")
    func testMagicModePenaltyIsSmall() {
        let baseDifficulty = 450
        let testTime = 600.0

        let withMagic = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 20,
            noteUpdates: 0
        )

        let withHint = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 1,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 0
        )

        // Hints should penalize more than losing the no-assistance bonus
        #expect(
            withHint.score < withMagic.score,
            "Hints should penalize more than using assistance (hint: \(withHint.score), magic: \(withMagic.score))"
        )
    }

    // MARK: - Note Update Penalty Tests

    @Test("Note updates reduce score with small penalty")
    func testNoteUpdatePenalty() {
        let baseDifficulty = 450
        let testTime = 600.0

        let noNotes = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 0
        )

        let someNotes = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 20
        )

        let lotsOfNotes = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 50
        )

        #expect(
            noNotes.score > someNotes.score,
            "Not using note updates should give bonus (got \(noNotes.score) vs \(someNotes.score))"
        )
        #expect(
            someNotes.score == lotsOfNotes.score,
            "Note update count shouldn't matter, only whether they were used (got \(someNotes.score) vs \(lotsOfNotes.score))"
        )
        #expect(
            noNotes.noAssistanceBonus == 1.15,
            "No assistance should give 15% bonus"
        )
        #expect(
            someNotes.noAssistanceBonus == 1.0,
            "Using note updates should give no bonus"
        )
    }

    @Test("Combined magic mode and note update penalties stack")
    func testCombinedPenalties() {
        let baseDifficulty = 450
        let testTime = 600.0

        let neither = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 0,
            noteUpdates: 0
        )

        let both = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0,
            magicModeInputs: 20,
            noteUpdates: 20
        )

        #expect(
            neither.score > both.score,
            "Using neither feature should score higher than using both"
        )

        // Using neither gets 15% bonus, using either gets no bonus
        #expect(
            neither.noAssistanceBonus == 1.15,
            "No assistance should give 15% bonus"
        )
        #expect(
            both.noAssistanceBonus == 1.0,
            "Using either assistance feature should give no bonus"
        )
    }

    // MARK: - Error Penalty Tests

    @Test("Errors reduce score exponentially")
    func testErrorPenalty() {
        let baseDifficulty = 450
        let testTime = 600.0

        let noErrors = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let oneError = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 1
        )

        let twoErrors = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 2
        )

        let fiveErrors = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 5
        )

        #expect(
            oneError.score < noErrors.score,
            "One error score (\(oneError.score)) should be less than no errors (\(noErrors.score))"
        )
        #expect(
            twoErrors.score < oneError.score,
            "Two errors score (\(twoErrors.score)) should be less than one error (\(oneError.score))"
        )
        #expect(
            fiveErrors.score < twoErrors.score,
            "Five errors score (\(fiveErrors.score)) should be less than two errors (\(twoErrors.score))"
        )

        // Verify exponential growth of penalty
        let oneErrorPenalty = 1.0 - oneError.errorPenalty
        let twoErrorPenalty = 1.0 - twoErrors.errorPenalty
        let penaltyIncrease = twoErrorPenalty - oneErrorPenalty

        #expect(
            penaltyIncrease > 0.15,
            "Penalty should grow significantly with each additional error"
        )
    }

    @Test("Error penalty is severe for multiple mistakes")
    func testSevereErrorPenalty() {
        let baseDifficulty = 450
        let testTime = 600.0

        let fiveErrors = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: testTime,
            hintsUsed: 0,
            errorCount: 5
        )

        // With 5 errors, penalty factor should be very low (~0.25, 75% penalty)
        #expect(
            fiveErrors.errorPenalty < 0.3,
            "Five errors should result in severe penalty factor (\(fiveErrors.errorPenalty))"
        )
    }

    // MARK: - Perfect Game Bonus Tests

    @Test("Perfect game receives bonus multiplier")
    func testPerfectGameBonus() {
        let baseDifficulty = 450

        // Perfect game (fast, no hints, no errors)
        let perfectResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 500,  // Under target for medium
            hintsUsed: 0,
            errorCount: 0
        )

        // Near-perfect but slightly slower
        let nearPerfectResult = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: 800,  // Over target
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            perfectResult.perfectBonus == true,
            "Fast completion with no hints/errors should receive perfect bonus"
        )
        #expect(
            nearPerfectResult.perfectBonus == false,
            "Slow completion should not receive perfect bonus even with no hints/errors"
        )
        #expect(
            perfectResult.score > nearPerfectResult.score,
            "Perfect game score should exceed near-perfect"
        )
    }

    @Test("Hints or errors prevent perfect bonus")
    func testPerfectBonusRequirements() {
        let baseDifficulty = 450
        let fastTime = 500.0  // Under target

        let withHint = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: fastTime,
            hintsUsed: 1,
            errorCount: 0
        )

        let withError = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: baseDifficulty,
            elapsedTime: fastTime,
            hintsUsed: 0,
            errorCount: 1
        )

        #expect(
            withHint.perfectBonus == false,
            "Hints should prevent perfect bonus"
        )
        #expect(
            withError.perfectBonus == false,
            "Errors should prevent perfect bonus"
        )
    }

    // MARK: - Difficulty Scaling Tests

    @Test("Harder puzzles yield higher potential scores")
    func testDifficultyScaling() {
        let perfectTime = 120.0  // 2 minutes (perfect for user requirement)

        let easyPerfect = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 150,
            elapsedTime: perfectTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let mediumPerfect = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,
            elapsedTime: perfectTime,
            hintsUsed: 0,
            errorCount: 0
        )

        let hardPerfect = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 800,
            elapsedTime: perfectTime,
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            mediumPerfect.score > easyPerfect.score,
            "Perfect medium score (\(mediumPerfect.score)) should exceed perfect easy (\(easyPerfect.score))"
        )
        #expect(
            hardPerfect.score > mediumPerfect.score,
            "Perfect hard score (\(hardPerfect.score)) should exceed perfect medium (\(mediumPerfect.score))"
        )

        // Hard puzzle completed quickly should approach maximum score
        #expect(
            hardPerfect.score >= 70_000,
            "Perfect hard puzzle should achieve high score (got \(hardPerfect.score))"
        )
    }

    // MARK: - Edge Cases

    @Test("Very slow completion produces minimum score")
    func testMinimumScore() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1,  // Easiest
            elapsedTime: 7200,  // 2 hours
            hintsUsed: 20,
            errorCount: 15
        )

        #expect(
            result.score >= 100,
            "Even worst performance should produce minimum score of 100"
        )
        #expect(
            result.score < 1000,
            "Very slow completion with many hints/errors should produce low score"
        )
    }

    @Test("Perfect hard puzzle approaches maximum score")
    func testMaximumScore() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1000,  // Hardest
            elapsedTime: 120,  // 2 minutes (extremely fast)
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 80_000,
            "Perfect very hard puzzle completed quickly should approach maximum score"
        )
        #expect(
            result.score <= 100_000,
            "Score should not exceed maximum of 100,000"
        )
        #expect(
            result.perfectBonus == true,
            "Should receive perfect bonus"
        )
    }

    @Test("Base difficulty is clamped to valid range")
    func testDifficultyClamping() {
        // Test below minimum
        let tooLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: -100,
            elapsedTime: 300,
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            tooLow.baseDifficulty == 1.0,
            "Negative difficulty should be clamped to 1"
        )

        // Test above maximum
        let tooHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 5000,
            elapsedTime: 300,
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            tooHigh.baseDifficulty == 2000.0,
            "Excessive difficulty should be clamped to 2000"
        )
    }

    @Test("Zero elapsed time is handled gracefully")
    func testZeroTime() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,
            elapsedTime: 0,  // Instant completion (unrealistic but should not crash)
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 100 && result.score <= 100_000,
            "Zero time should produce valid score"
        )
        // Should receive maximum time multiplier (3.0)
        #expect(
            result.timeMultiplier >= 2.5,
            "Zero/instant time should produce very high multiplier"
        )
    }

    // MARK: - Real-World Scenarios

    @Test("Typical easy puzzle completion scenario")
    func testTypicalEasyCompletion() {
        // Average player: 5 minutes, 1 hint, 1 error
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 150,
            elapsedTime: 300,  // 5 minutes
            hintsUsed: 1,
            errorCount: 1,
            magicModeInputs: 0,
            noteUpdates: 0
        )

        #expect(
            result.score >= 5_000 && result.score <= 35_000,
            "Typical easy completion should score in mid-range (got \(result.score))"
        )
        #expect(
            result.perfectBonus == false,
            "Should not receive perfect bonus"
        )
    }

    @Test("Excellent medium puzzle completion scenario")
    func testExcellentMediumCompletion() {
        // Skilled player: 8 minutes, 0 hints, 0 errors
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,
            elapsedTime: 480,  // 8 minutes
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 30_000 && result.score <= 100_000,
            "Excellent medium completion should score high (got \(result.score))"
        )
        #expect(
            result.perfectBonus == true,
            "Should receive perfect bonus for flawless fast completion"
        )
    }

    @Test("User requirement: slow easy with hints scores ~100")
    func testUserMinimumRequirement() {
        // Slow easy puzzle with multiple hints
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 50,  // Very easy
            elapsedTime: 1800,  // 30 minutes (very slow)
            hintsUsed: 10,
            errorCount: 5
        )

        #expect(
            result.score >= 100 && result.score <= 2_000,
            "Slow easy puzzle with many hints should score near minimum (got \(result.score))"
        )
    }

    @Test("User requirement: hard puzzle under 2min scores ~100,000")
    func testUserMaximumRequirement() {
        // Hard puzzle completed quickly without errors/hints
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 800,
            elapsedTime: 110,  // 1:50 (under 2 minutes)
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 70_000,
            "Hard puzzle under 2 minutes should score very high (got \(result.score))"
        )
        #expect(
            result.perfectBonus == true,
            "Should receive perfect bonus"
        )
    }

    // MARK: - Result Structure Tests

    @Test("Performance result captures all calculation details")
    func testResultStructure() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 450,
            elapsedTime: 600.0,
            hintsUsed: 2,
            errorCount: 1
        )

        #expect(
            result.score > 0,
            "Should have valid score"
        )
        #expect(
            result.baseDifficulty == 450,
            "Should capture base difficulty"
        )
        #expect(
            result.timeMultiplier > 0,
            "Should have time multiplier"
        )
        #expect(
            result.hintPenalty >= 0.0 && result.hintPenalty <= 1.0,
            "Hint penalty should be in 0-1 range"
        )
        #expect(
            result.errorPenalty >= 0.0 && result.errorPenalty <= 1.0,
            "Error penalty should be in 0-1 range"
        )
        #expect(
            result.elapsedTime == 600.0,
            "Should capture elapsed time"
        )
        #expect(
            result.hintsUsed == 2,
            "Should capture hints used"
        )
        #expect(
            result.errorCount == 1,
            "Should capture error count"
        )
    }

    // MARK: - Maximum Score Per Difficulty Tests

    @Test("Maximum achievable score for Easy difficulty (15 second minimum)")
    func testMaximumEasyScore() {
        // Low end of easy difficulty
        let easyLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 150,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            easyLow.score >= 60_000 && easyLow.score <= 70_000,
            "Easy low (150) max score should be 60k-70k (got \(easyLow.score))"
        )

        // High end of easy difficulty
        let easyHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 300,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            easyHigh.score >= 70_000 && easyHigh.score <= 76_000,
            "Easy high (300) max score should be 70k-76k (got \(easyHigh.score))"
        )
        #expect(easyHigh.perfectBonus == true, "Should receive perfect bonus")
    }

    @Test("Maximum achievable score for Medium difficulty (15 second minimum)")
    func testMaximumMediumScore() {
        // Low end of medium difficulty
        let mediumLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 310,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            mediumLow.score >= 70_000 && mediumLow.score <= 76_000,
            "Medium low (310) max score should be 70k-76k (got \(mediumLow.score))"
        )

        // High end of medium difficulty
        let mediumHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 600,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            mediumHigh.score >= 80_000 && mediumHigh.score <= 86_000,
            "Medium high (600) max score should be 80k-86k (got \(mediumHigh.score))"
        )
        #expect(mediumHigh.perfectBonus == true, "Should receive perfect bonus")
    }

    @Test("Maximum achievable score for Hard difficulty (15 second minimum)")
    func testMaximumHardScore() {
        // Low end of hard difficulty
        let hardLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 601,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            hardLow.score >= 80_000 && hardLow.score <= 86_000,
            "Hard low (601) max score should be 80k-86k (got \(hardLow.score))"
        )

        // High end of hard difficulty
        let hardHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1000,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            hardHigh.score >= 88_000 && hardHigh.score <= 93_000,
            "Hard high (1000) max score should be 88k-93k (got \(hardHigh.score))"
        )
        #expect(hardHigh.perfectBonus == true, "Should receive perfect bonus")
    }

    @Test("Maximum achievable score for Expert difficulty (15 second minimum)")
    func testMaximumExpertScore() {
        // Low end of expert difficulty
        let expertLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1001,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            expertLow.score >= 88_000 && expertLow.score <= 93_000,
            "Expert low (1001) max score should be 88k-93k (got \(expertLow.score))"
        )

        // High end of expert difficulty
        let expertHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1600,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            expertHigh.score >= 95_000 && expertHigh.score <= 99_000,
            "Expert high (1600) max score should be 95k-99k (got \(expertHigh.score))"
        )
        #expect(expertHigh.perfectBonus == true, "Should receive perfect bonus")
    }

    @Test("Maximum achievable score for Professional difficulty (15 second minimum)")
    func testMaximumProfessionalScore() {
        // Low end of professional difficulty
        let proLow = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1601,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            proLow.score >= 95_000 && proLow.score <= 99_000,
            "Professional low (1601) max score should be 95k-99k (got \(proLow.score))"
        )

        // High end of professional difficulty (maximum realistic)
        let proHigh = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 2000,
            elapsedTime: 15.0,
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            proHigh.score >= 99_000 && proHigh.score <= 100_000,
            "Professional high (2000) max score should be 99k-100k (got \(proHigh.score))"
        )
        #expect(proHigh.perfectBonus == true, "Should receive perfect bonus")
    }

    @Test("15-second minimum ensures all difficulties receive perfect bonus")
    func testFifteenSecondPerfectBonus() {
        // Verify that 15 seconds is under target time for all difficulties
        let difficulties: [Int] = [150, 300, 310, 600, 601, 1000, 1001, 1600, 1601, 2000]

        for difficulty in difficulties {
            let result = PerformanceScoreCalculator.calculateScore(
                baseDifficulty: difficulty,
                elapsedTime: 15.0,
                hintsUsed: 0,
                errorCount: 0
            )
            #expect(
                result.perfectBonus == true,
                "Difficulty \(difficulty) should receive perfect bonus at 15 seconds"
            )
        }
    }

    // MARK: - Extreme Edge Case Tests

    @Test(
        "Absolute best case: 10 second solve on hardest 2000 difficulty puzzle with no hints or mistakes"
    )
    func testAbsoluteBestCase() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 2000,  // Hardest possible puzzle
            elapsedTime: 10.0,  // Impossibly quick 10 seconds
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 99_000 && result.score <= 100_000,
            "Absolute best case should approach maximum (got \(result.score))"
        )
        #expect(
            result.score <= 100_000,
            "Score should not exceed maximum"
        )
        #expect(
            result.perfectBonus == true,
            "Should receive perfect bonus"
        )
        #expect(
            result.timeMultiplier >= 2.9,
            "Should have near-maximum time multiplier"
        )
        #expect(
            result.hintPenalty == 1.0,
            "Should have no hint penalty"
        )
        #expect(
            result.errorPenalty == 1.0,
            "Should have no error penalty"
        )
    }

    @Test(
        "Absolute worst case: 3 hour solve on easiest 200 difficulty puzzle with 70 hints and many mistakes"
    )
    func testAbsoluteWorstCase() {
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 200,  // Easy puzzle
            elapsedTime: 10800.0,  // 3 hours (extremely slow)
            hintsUsed: 70,
            errorCount: 50
        )

        #expect(
            result.score >= 100,
            "Should still achieve minimum score of 100 (got \(result.score))"
        )
        #expect(
            result.score <= 1_000,
            "Worst case should produce very low score (got \(result.score))"
        )
        #expect(
            result.perfectBonus == false,
            "Should not receive perfect bonus"
        )
        #expect(
            result.timeMultiplier <= 0.5,
            "Should have very low time multiplier"
        )
        #expect(
            result.hintPenalty <= 0.1,
            "Should have severe hint penalty"
        )
        #expect(
            result.errorPenalty <= 0.01,
            "Should have severe error penalty"
        )
    }

    @Test("Real-world maximum achievable score")
    func testRealWorldMaximum() {
        // More realistic "perfect" scenario: professional puzzle in 2 minutes
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 2000,
            elapsedTime: 120.0,  // 2 minutes
            hintsUsed: 0,
            errorCount: 0
        )

        #expect(
            result.score >= 85_000,
            "Real-world perfect should score very high (got \(result.score))"
        )
        #expect(
            result.score <= 100_000,
            "Should not exceed maximum"
        )
        #expect(
            result.perfectBonus == true,
            "Should receive perfect bonus"
        )
    }

    @Test("Real-world minimum with casual play")
    func testRealWorldMinimum() {
        // Casual player struggling with easy puzzle
        let result = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 200,
            elapsedTime: 1800.0,  // 30 minutes
            hintsUsed: 15,
            errorCount: 10
        )

        #expect(
            result.score >= 100,
            "Should maintain minimum score (got \(result.score))"
        )
        #expect(
            result.score <= 5_000,
            "Casual struggling play should score low (got \(result.score))"
        )
        #expect(
            result.perfectBonus == false,
            "Should not receive perfect bonus"
        )
    }

    @Test("Score scales correctly across full range")
    func testFullScoreRange() {
        // Test that we can achieve scores across the full 100-100,000 range

        // Bottom tier: minimum score of 100
        let veryBad = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 200,
            elapsedTime: 7200.0,  // 2 hours
            hintsUsed: 50,
            errorCount: 30
        )
        #expect(
            veryBad.score == 100,
            "Very bad performance should hit minimum score of 100 (got \(veryBad.score))"
        )

        // Low tier: ~100-5,000
        let poor = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 400,
            elapsedTime: 1500.0,  // 25 minutes
            hintsUsed: 8,
            errorCount: 2
        )
        #expect(
            poor.score >= 100 && poor.score <= 10_000,
            "Poor performance should score 100-10k range (got \(poor.score))"
        )

        // Mid tier: ~40,000-50,000
        let average = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 600,
            elapsedTime: 1200.0,  // 20 minutes
            hintsUsed: 2,
            errorCount: 1
        )
        #expect(
            average.score >= 35_000 && average.score <= 55_000,
            "Average performance should score 35k-55k range (got \(average.score))"
        )

        // High tier: ~85,000-95,000
        let good = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 1600,
            elapsedTime: 1800.0,  // 30 minutes
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            good.score >= 85_000 && good.score <= 95_000,
            "Good performance should score 85k-95k range (got \(good.score))"
        )

        // Pro tier: maximum score of 100,000
        let pro = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 2000,
            elapsedTime: 1200.0,  // 20 minutes
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            pro.score >= 90_000 && pro.score < 100_000,
            "Good performance should score 95k-100k range (got \(pro.score))"
        )

        // Top tier: approaching maximum
        let excellent = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 2000,
            elapsedTime: 30.0,  // 30 Seconds
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            excellent.score >= 99_000 && excellent.score <= 100_000,
            "Excellent performance should approach maximum (got \(excellent.score))"
        )

        // Impossible tier: maximum score
        let impossible = PerformanceScoreCalculator.calculateScore(
            baseDifficulty: 9999,
            elapsedTime: 1,  // 1 Seconds
            hintsUsed: 0,
            errorCount: 0
        )
        #expect(
            impossible.score >= 99_000 && impossible.score <= 100_000,
            "Even an impossible puzzle should cap at maximum (got \(impossible.score))"
        )
    }
}
