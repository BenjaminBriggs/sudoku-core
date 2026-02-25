//
//  HintEmptyRectangleTests.swift
//  SudokuCore
//
//  Created by Claude on 25/02/2026.
//

import Testing

@testable import SudokuCore

struct HintEmptyRectangleTests {

    // MARK: - Helpers

    /// Repeatedly applies simpler techniques until the target technique is found
    /// or no more progress can be made.
    private func solveUntilTechnique(
        _ target: HintTechnique,
        state: BoardState,
        maxSteps: Int = 200
    ) -> (state: BoardState, hint: HintStep?) {
        var current = state
        let simplerTechniques = HintTechnique.orderedCases.filter { $0.difficulty < target.difficulty }

        for _ in 0..<maxSteps {
            // Check if target technique is available
            if let hint = HintFinder.findHint(for: target, in: current) {
                return (current, hint)
            }

            // Apply simpler techniques
            var madeProgress = false
            for technique in simplerTechniques {
                if let hint = HintFinder.findHint(for: technique, in: current) {
                    current = current.applying(hint)
                    madeProgress = true
                    break
                }
            }

            if madeProgress == false { break }
        }

        return (current, HintFinder.findHint(for: target, in: current))
    }

    // MARK: - No pattern on empty/solved boards

    @Test("Returns nil on empty board")
    func returnsNilOnEmptyBoard() {
        let grid = Solution.empty()
        let pencilMarks = Validator.validOptions(for: grid)
        let state = BoardState(grid: grid, pencilMarks: pencilMarks, validOptions: pencilMarks)
        let hint = HintFinder.findHint(for: .emptyRectangle, in: state)
        #expect(hint == nil, "Should not find Empty Rectangle on empty board")
    }

    @Test("Returns nil on solved board")
    func returnsNilOnSolvedBoard() {
        let grid = Solution.cells(from: "123456789456789123789123456231564897564897231897231564312645978645978312978312645")
        let state = BoardState.fromGrid(grid)
        let hint = HintFinder.findHint(for: .emptyRectangle, in: state)
        #expect(hint == nil, "Should not find Empty Rectangle on solved board")
    }

    // MARK: - Pattern detection with known grids

    /// Puzzles that require Empty Rectangle at some point in their solve path.
    /// These use the sudoku.coach encoded format which preserves intermediate solve state.
    static let emptyRectangleGrids: [String] = [
        "SCv7_32_f2e4r3ib1r130324tu97aaqdab3n3m621ks439a6akic90mv0b2drccr09ah8uvsti4v6snjkl7cfuhcdqbjmdun8sshvqisdtbresu43o9344g0ko2bua4v176a1b1t8kv0b9i1n4al2e9056l160qoij0ism85qusvndasurin9mkfsukktotdr0hf8tl8klak94iu41uopf7242h52lsppre17v9dhnvdts236dsrca7ohqqp6m0mcpchf1dd8epebq2pn5m3os9g8al5g6lnj6r22chdrvals2lbd9ell8k0rjtg741f9m90",
        "SCv7_32_f2e5ajmb1r12047s2v72a6b0b70qnvk1bv8a991164f6ptd0u7ftqrfhq489d7ctjkcpsplsqrgl87u5thpmfhjq5ubm67fb7icrq0brgu6104803seq0lrq5k611o0s8m047hge5506gmd4lhnm0kciptle2p25sqj37dt9bg7uav1uuibq23ntbgqchrtsolp448l9caua0tee0idt05k8p5j5tupfk4l2b24j9m0ma4gt5vpm88pdhq11bocridddc1rt6hk0lptsik2vsqemjjgcb3eirtnrfv5mmphlsrqost6mg",
        "SCv7_32_f2e6ajib1o12235t1fli2uck0b2qrnm02ec0p6cg30bvs5gqttn425l3grqbbrqjs1kpcsstuvql3j169tjajtrirbaqanhfcphm42huieo67u44j0km8k384g1aq00l38ta8dhb80q8921kkg8aahsgagrp7eatp9sln3m7tngj9lvpe0muq8eovt1k3fhqfrc6l2mhua3nh415q61eb3u5hah46khhosf75o4emppq57jb5f1hvqekbkcklesvr2tdc7erikl65f8nplpvvibgr2udt3gs9bfg",
        "SCv7_32_f2e5qjmbh81j237riue1n40tou9v9mntgfuo5gk44587lq7bq2pfvfnmci38b38fm5i4jth75irjsvvnes5seug89dvrbqqnbvte67ke07898096g8vmv4d9094p835ik051f7bak9m57409a0pnm9o9nbt740e47odocgrorrdurl1eiv9viennv7u6hfh82m4piiu4b8i14iul1niq8di32h4f8ju5p34g0ldmpqmpnjbgcb2bqa3p0jlphvv9vqbofaskp29uesbh9o68vv6t7e97erj4jd7u2hqhcq5thh3uoqtcp6b9t3ult14vbutq0jh6",
        "SCv7_32_f2e9aji1d81j237shf7h3335r6b76jbvq0bg9lhcgq8474nmq39bultid4gseu44kkckj35uodv1nmvrv3le3m0ec4fpvvfq6rrf3e47cf4aho462gduo2e06dg385idhklp1e29pkd8nvahhf8tl151nq8ufkjv1m247u5ouvdqinpekvpna6urv78tq264ik4p8674q2akobk5la89go09qj5aplp4lfnkh71366kp7h0kdcgjogek0cnm16f9ug1hanaign5usl2dihqofv0tj6jqutuln3ehecs7jtfvjnabsg",
        "SCv7_32_f2e7ajibdp1i235s1fli13cd6686quk3jogd4gqf918hcieq8mltpf9mlsnrmo7sidjupu8dtdmip7v3ku3m6es4eluffqu7b33u67keg4c4i1a008l1h0had3b869anjfd2n554d7jal3djps4q0cmhuratnpj4bd1gh1vgennrektvbh7efqpiirpq7up18h22q71hlkr8r3bb4jqos6m7iba2mta45rai5cqctib7roj8gpishvsupn4bh1bon8kotrsdsqajqpshv2999cqnvfl1qa0uibkp7ae236dtt7dirnhs9ofp0t3b4j8h",
        "SCv7_32_f2e7aji91r1i037s1fjk9ckd069mnuk3nog54k442jip191tmjlduqtil6bo5s1mcdjdspkoedvsvbr4j9c9i89vqdqcmgqu2v9hht04dg2q52u11cp5ioab26r17b83080gmgmqdkqilpk3gar79480gea4t0un9ij353p5plmhlhtmjftdotrb591515sbfr7rvldvbcc48vjrdaphc7ep2daf2gj1lt8slg7i6knm9hc2bgpcgv3sl6kepd9e41peq3gvdqhrmgoqt4q02ih3l1cnc5gs1fdfng5r07pvi0jbmt5v0",
        "SCv7_32_f2e5ajib1913235s9fbgdkhk9l9beug39sgbpsh8h05nu2u5nedigjphk7ssoj4o7r97o6mjdre7mmlnamdcfb8vmthht5rjb8ji3p521khi96rqaemcqkehhi2notsijbal0636ol7mgtcim4l724qn62d685t5amt9tur9qc7ofjfu726mivv9c6280g1dt8jm73inomg55t0vis4ph0a48brqtu1nn712bkedc4iigdamc98fk688209e8ojf1s272vlpc746gk04ajelk1dcu3rj5c3vndilvc7ou29c5ph6iaf2u44l9kkg",
    ]

    @Test("Finds Empty Rectangle in known grids", arguments: emptyRectangleGrids)
    func findsEmptyRectangle(gridString: String) {
        let state: BoardState
        do {
            state = try BoardStateParser.parse(gridString)
        } catch {
            Issue.record("Failed to parse grid string: \(error)")
            return
        }

        let hint = HintFinder.findHint(for: .emptyRectangle, in: state)
        #expect(hint != nil, "Expected to find Empty Rectangle in grid: \(gridString)")

        if let hint {
            #expect(hint.technique == .emptyRectangle, "Technique should be emptyRectangle")

            // All actions should be ruleOut
            for action in hint.actions {
                if case .ruleOut(_) = action.action {
                    // correct
                } else {
                    Issue.record("Expected ruleOut action, got \(action.debugDescription)")
                }
            }

            // Should have 4 explanation steps
            #expect(hint.explanation.count == 4, "Expected 4 explanation steps, got \(hint.explanation.count)")

            // Applying the hint should not create conflicts
            let newState = state.applying(hint)
            #expect(
                Validator.hasNoConflicts(in: newState.grid),
                "Applying hint should not create conflicts"
            )
        }
    }

    // MARK: - Technique metadata

    @Test("Technique metadata is correct")
    func techniqueMetadata() {
        #expect(HintTechnique.emptyRectangle.difficulty == 92)
        #expect(HintTechnique.emptyRectangle.seId == "Empty Rectangle")
        #expect(HintTechnique.emptyRectangle.seStepValue == 4.0)
        #expect(HintTechnique.emptyRectangle.hodokuPoints == 80)
    }
}
