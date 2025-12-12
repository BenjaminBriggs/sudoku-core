import Testing
@testable import SudokuCore

@Suite("TimeEstimator")
struct TimeEstimatorTests {
    @Test("Baseline increases with rating and applies personalization")
    func baselineAndPersonalization() {
        let r1 = 100
        let r2 = 600
        let b1 = TimeEstimator.baselineSeconds(fromHoDoKu: r1)
        let b2 = TimeEstimator.baselineSeconds(fromHoDoKu: r2)
        #expect(b2 > b1)

        let est = TimeEstimator.estimate(fromHoDoKu: r2, userSpeedFactor: 0.8)
        #expect(est.personalizedSeconds != nil)
        #expect(est.rangeUpper > est.rangeLower)
    }
}
