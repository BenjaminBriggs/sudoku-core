import Foundation
import Testing

@testable import SudokuCore

@Suite("PersonalizedCalibrator")
struct PersonalizedCalibratorTests {
    @Test("Baseline interpolation works at anchors")
    func baseline() {
        let cal = PersonalizedCalibrator()
        #expect(
            cal.baselineSeconds(for: 100) >= 180 - 5 && cal.baselineSeconds(for: 100) <= 180 + 5)
        #expect(
            cal.baselineSeconds(for: 1600) >= 3000 - 10
                && cal.baselineSeconds(for: 1600) <= 3000 + 10)
    }

    @Test("Interpolates factor between neighbors and clamps extremes")
    func interpolation() {
        var cal = PersonalizedCalibrator()
        // Suppose user is twice as fast at 300 and equal at 1000
        let base300 = cal.baselineSeconds(for: 300)
        let base1000 = cal.baselineSeconds(for: 1000)
        cal.update(rating: 300, timeSeconds: base300 / 2)
        cal.update(rating: 1000, timeSeconds: base1000)

        let estMid = cal.predict(for: 600)
        // Factor should be between 0.5 and 1.0
        #expect(estMid.factor > 0.5 && estMid.factor < 1.0)
        #expect(estMid.seconds > 0)
        // Extrapolation below minimum blends toward baseline (factor→1)
        let estLow = cal.predict(for: 150)
        #expect(estLow.factor > 0.5)
    }

    @Test("No samples -> baseline estimate with default range")
    func noSamples() {
        let cal = PersonalizedCalibrator()
        let est = cal.predict(for: 800)
        #expect(est.seconds == cal.baselineSeconds(for: 800))
        #expect(est.rangeUpper > est.seconds)
        #expect(est.rangeLower < est.seconds)
    }

    @Test("Clamps extreme factors and drops oldest samples")
    func clampingAndCapacity() {
        var cal = PersonalizedCalibrator(maxSamples: 3)
        // Extreme fast at 100 (would be < 0.2 factor without clamp)
        let base100 = cal.baselineSeconds(for: 100)
        cal.update(
            rating: 100, timeSeconds: Int(Double(base100) * 0.05),
            at: Date(timeIntervalSince1970: 0))
        // Add two more within capacity
        cal.update(
            rating: 300, timeSeconds: cal.baselineSeconds(for: 300),
            at: Date(timeIntervalSince1970: 1))
        cal.update(
            rating: 600, timeSeconds: cal.baselineSeconds(for: 600),
            at: Date(timeIntervalSince1970: 2))
        #expect(cal.sampleCount == 3)
        // Add one more; oldest should be dropped (the 100 rating)
        cal.update(
            rating: 1000, timeSeconds: cal.baselineSeconds(for: 1000),
            at: Date(timeIntervalSince1970: 3))
        #expect(cal.sampleCount == 3)
        // Predict near 100; clamped factor prevents unrealistic estimates
        let est = cal.predict(for: 100)
        #expect(est.factor >= 0.2)
    }
}
