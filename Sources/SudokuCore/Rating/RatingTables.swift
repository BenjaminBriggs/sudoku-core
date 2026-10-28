//
//  RatingTables.swift
//  SudokuCore
//
//  Swift-native default tables for SE, HoDoKu and time mapping.
//  Replace values during calibration as needed; calculators can also accept
//  injected tables for tests or alternative configurations.
//

import Foundation

public enum RatingTables {
    public enum HoDoKu {
        /// HoDoKu 2.6's default solver step for each classic technique: its place in HoDoKu's
        /// solve order, the points it scores and the level it gives a puzzle.
        ///
        /// A full house is a naked single, and a Crane one of HoDoKu's Turbot Fish. HoDoKu has no
        /// 4- to 7-Y-Wing; it finds them as XY-Chains, so they score as XY-Chains, last.
        public static let steps: [TechniqueID: (order: Int, points: Int, level: HoDoKuLevel)] = [
            TechniqueInfo.nakedSingle.id: (200, 4, .easy),
            TechniqueInfo.hiddenSingle.id: (300, 14, .easy),
            TechniqueInfo.lockedCandidatesPointing.id: (1200, 50, .medium),
            TechniqueInfo.lockedCandidatesClaiming.id: (1210, 50, .medium),
            TechniqueInfo.nakedPair.id: (1300, 60, .medium),
            TechniqueInfo.nakedTriple.id: (1400, 80, .medium),
            TechniqueInfo.hiddenPair.id: (1500, 70, .medium),
            TechniqueInfo.hiddenTriple.id: (1600, 100, .medium),
            TechniqueInfo.nakedQuad.id: (2000, 120, .hard),
            TechniqueInfo.hiddenQuad.id: (2100, 150, .hard),
            TechniqueInfo.xWing.id: (2200, 140, .hard),
            TechniqueInfo.swordfish.id: (2300, 150, .hard),
            TechniqueInfo.jellyfish.id: (2400, 160, .hard),
            TechniqueInfo.bug.id: (2900, 100, .hard),
            TechniqueInfo.skyscraper.id: (3000, 130, .hard),
            TechniqueInfo.twoStringKite.id: (3100, 150, .hard),
            TechniqueInfo.crane.id: (3120, 120, .hard),
            TechniqueInfo.emptyRectangle.id: (3170, 120, .hard),
            TechniqueInfo.wWing.id: (3200, 150, .hard),
            TechniqueInfo.xyWing.id: (3300, 160, .hard),
            TechniqueInfo.xyzWing.id: (3400, 180, .hard),
            TechniqueInfo.uniqueRectangleType1.id: (3500, 100, .hard),
            TechniqueInfo.uniqueRectangleType2.id: (3600, 100, .hard),
            TechniqueInfo.uniqueRectangleType3.id: (3700, 100, .hard),
            TechniqueInfo.uniqueRectangleType4.id: (3800, 100, .hard),
            TechniqueInfo.uniqueRectangleType5.id: (3900, 100, .hard),
            TechniqueInfo.finnedXWing.id: (4100, 130, .hard),
            TechniqueInfo.finnedSwordfish.id: (4300, 200, .unfair),
            TechniqueInfo.finnedJellyfish.id: (4500, 250, .unfair),
            TechniqueInfo.fourYWing.id: (5500, 260, .unfair),
            TechniqueInfo.fiveYWing.id: (5501, 260, .unfair),
            TechniqueInfo.sixYWing.id: (5502, 260, .unfair),
            TechniqueInfo.sevenYWing.id: (5503, 260, .unfair),
        ]
    }

    public enum TimeMapping {
        /// Log-linear model parameters for baseline minutes.
        public static let logModel: (a: Double, b: Double) = (2.0, 2.2)

        /// Optional class-based ranges (minutes); can be used for UI hints.
        public static let classRangesMinutes: [String: (min: Int, max: Int)] = [
            "Basic": (2, 4),
            "Easy": (4, 8),
            "Moderate": (8, 15),
            "Hard": (15, 25),
            "Very Hard": (25, 40),
            "Extreme": (40, 90),
        ]
    }
}
