//
//  TechniqueOrderTests.swift
//  SudokuCore
//
//  Where two techniques apply, the hint is the one players are taught first. Skyscraper is tried
//  before the finned fish, since almost every Skyscraper is also a sashimi Finned X-Wing; Unique
//  Rectangle Type 1 straight after X-Wing, where SudokuWiki tries it, so before the XY-Wing; and
//  XY-Wing before W-Wing.
//
//  BUG+1 comes before X-Wing too, but no position shows it: the two never both apply on a puzzle
//  with one solution. In a BUG+1 position every digit has two homes in each row, column and box,
//  but the extra digit has three in the BUG square's row, column and box, so an X-Wing could
//  only cross that digit off the BUG square, where BUG+1 places it. None of 25,311 shipped,
//  fixture and generated puzzles has such a position on its solve path.
//
import Testing
@testable import SudokuCore

struct TechniqueOrderTests {
    /// Step 45 of a shipped Advanced puzzle (060040900703016000050700008…), with no notes ruled
    /// out by earlier steps. Rows 4 and 7 hold 4 only in column 4 and in r4c7 and r7c9, so
    /// r6c9, which sees both, isn't 4. A sashimi Finned X-Wing on the same rows crosses off the
    /// same note.
    static let skyscraperState = BoardState.fromGrid(Solution.cells(
        from: "168040973793816000452739168276098031549123786381670290627081350915360807834057610"))

    /// Step 25 of a shipped Expert puzzle (040800201500000000108400060…), with no notes ruled out
    /// by earlier steps. A Unique Rectangle Type 1, an XY-Wing and a W-Wing all apply.
    static let rectangleState = BoardState.fromGrid(Solution.cells(
        from: "040800201500000008108400067214090785800157624756284193401500379900700006075900802"),
        assumingUniqueSolution: true)

    /// Step 42 of a shipped Advanced puzzle (010740500380000009000000070…), with no notes ruled
    /// out by earlier steps. An XY-Wing and a W-Wing apply, and no Unique Rectangle.
    static let xyWingState = BoardState.fromGrid(Solution.cells(
        from: "216749583387001009549003070650002730920037065730165900872006314465318297193274856"),
        assumingUniqueSolution: true)

    static func ruleOut(_ digit: Int, _ cells: (row: Int, column: Int)...) -> Set<HintAction> {
        Set(cells.map { HintAction(position: Puzzle.Index(row: $0.row - 1, column: $0.column - 1), ruleOut: digit) })
    }

    @Test("Where a sashimi Finned X-Wing crosses off the same notes, the hint is the Skyscraper")
    func skyscraperBeforeSashimi() throws {
        let state = Self.skyscraperState
        let skyscraper = try #require(SkyscraperTechnique().findHint(in: state))
        let finned = try #require(FishTechnique(size: 2, finned: true).findHint(in: state))
        #expect(Set(skyscraper.actions) == Self.ruleOut(4, (6, 9)))
        #expect(Set(finned.actions) == Set(skyscraper.actions))
        // Sashimi: row 4 has no 4 in the fish's second column, so the fish has three base squares
        #expect(finned.reasoning.components.first { $0.role == .base }?.cells.count == 3)

        let hint = try #require(HintFinder.firstHint(in: state))
        #expect(hint.technique == .skyscraper)
        #expect(Set(hint.actions) == Set(skyscraper.actions))
    }

    @Test("Where an XY-Wing and a W-Wing also apply, the hint is the Unique Rectangle Type 1")
    func rectangleBeforeWings() throws {
        let state = Self.rectangleState
        // The rectangle's argument needs one solution, and the position has one
        #expect(Validator.solutionCount(of: state.grid).isUnique)
        let xyWing = try #require(XYWingTechnique().findHint(in: state))
        let wWing = try #require(WWingTechnique().findHint(in: state))
        let rectangle = try #require(UniqueRectangleTechnique(type: 1).findHint(in: state))
        #expect(Set(xyWing.actions) == Self.ruleOut(6, (1, 5), (2, 5)))
        #expect(Set(wWing.actions) == Self.ruleOut(6, (1, 5), (1, 6), (2, 2)))
        #expect(Set(rectangle.actions) == Self.ruleOut(3, (2, 6)).union(Self.ruleOut(6, (2, 6))))

        // The XY-Wing was the hint when Type 1 came after the wings
        let hint = try #require(HintFinder.firstHint(in: state))
        #expect(hint.technique == .uniqueRectangleType1)
        #expect(Set(hint.actions) == Set(rectangle.actions))
    }

    @Test("Where a W-Wing also applies, the hint is the XY-Wing")
    func xyWingBeforeWWing() throws {
        let state = Self.xyWingState
        let xyWing = try #require(XYWingTechnique().findHint(in: state))
        let wWing = try #require(WWingTechnique().findHint(in: state))
        #expect(UniqueRectangleTechnique(type: 1).findHint(in: state) == nil)
        #expect(Set(xyWing.actions) == Self.ruleOut(8, (4, 5)))
        #expect(Set(wWing.actions) == Self.ruleOut(8, (5, 3)))

        let hint = try #require(HintFinder.firstHint(in: state))
        #expect(hint.technique == .xyWing)
        #expect(Set(hint.actions) == Set(xyWing.actions))
    }

    @Test("firstHint finds the same technique when handed the techniques out of order",
          arguments: [(skyscraperState, TechniqueInfo.skyscraper), (rectangleState, .uniqueRectangleType1),
                      (xyWingState, .xyWing)])
    func outOfOrder(_ state: BoardState, _ technique: TechniqueInfo) throws {
        var generator = SplitMix64(seed: "technique-order/\(technique.id)")
        let orders = [Array(ClassicTechniques.all.reversed()), ClassicTechniques.all.shuffled(using: &generator)]
        for techniques in orders {
            let hint = try #require(HintFinder.firstHint(in: state, using: techniques))
            #expect(hint.technique == technique)
        }
    }
}
