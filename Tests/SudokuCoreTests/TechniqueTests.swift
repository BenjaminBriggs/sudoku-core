import Foundation
import Testing

@testable import SudokuCore

struct TechniqueTests {

    @Test("TechniqueID decodes from a legacy bare string")
    func legacyDecode() throws {
        let data = Data("\"nakedSingle\"".utf8)
        let id = try JSONDecoder().decode(TechniqueID.self, from: data)
        #expect(id == TechniqueInfo.nakedSingle.id)
        #expect(id.rawValue == "nakedSingle")
    }

    @Test("TechniqueID encodes as a bare string")
    func bareStringEncode() throws {
        let data = try JSONEncoder().encode(TechniqueInfo.finnedXWing.id)
        #expect(String(decoding: data, as: UTF8.self) == "\"finnedXWing\"")
    }

    @Test("firstHint respects difficulty order even with unsorted input")
    func firstHintOrdersUnsortedTechniques() throws {
        struct AlwaysFinds: HintTechnique {
            let info: TechniqueInfo
            func findHint(in state: BoardState) -> HintStep? {
                HintStep(actions: [], technique: info)
            }
        }
        let easy = AlwaysFinds(info: TechniqueInfo(id: "test.easy", difficulty: 10))
        let hard = AlwaysFinds(info: TechniqueInfo(id: "test.hard", difficulty: 50))

        let state = BoardState.fromGrid(Puzzle.example().startingState)
        let hint = try #require(HintFinder.firstHint(in: state, using: [hard, easy]))
        #expect(hint.technique.id == easy.info.id)
    }

    @Test("Classic constants preserve enum metadata")
    func classicMetadata() {
        #expect(TechniqueInfo.nakedSingle.difficulty == 10)
        #expect(TechniqueInfo.nakedSingle.scorePoints == 4)
        #expect(TechniqueInfo.nakedSingle.seStepValue == 1.2)
        #expect(TechniqueInfo.nakedSingle.seId == "Single")
        #expect(TechniqueInfo.validation.difficulty == 0)
        #expect(TechniqueInfo.unknown.difficulty == 9999)
        #expect(TechniqueInfo.xyzWing.scorePoints == 180)
        // 35 = 33 real techniques + validation + unknown, one per legacy enum case.
        #expect(TechniqueInfo.allClassic.count == 35)
    }

    @Test("Classic points and levels are HoDoKu's step scores and levels")
    func classicPointsAreHoDoKus() {
        for info in TechniqueInfo.allClassic where info != .validation && info != .unknown {
            let step = RatingTables.HoDoKu.steps[info.id]
            #expect(info.scorePoints == step.map { Double($0.points) }, "\(info.id)")
            let level: PuzzleDifficulty.Level? = switch step?.level {
            case .easy: .easy
            case .medium: .medium
            case .hard: .hard
            case .unfair: .expert
            case .extreme: .professional
            case nil: nil
            }
            #expect(info.level == level, "\(info.id)")
            #expect(info.isSingle == (info == .nakedSingle || info == .hiddenSingle), "\(info.id)")
        }
        #expect(TechniqueInfo.validation.scorePoints == 0)
        #expect(TechniqueInfo.validation.level == .easy)
        // Guessing is costed like the hardest techniques, not HoDoKu's 20000-point give-up
        #expect(TechniqueInfo.unknown.scorePoints == 300)
        #expect(TechniqueInfo.unknown.level == .professional)
        #expect(TechniqueInfo.unknown.isSingle == false)
    }

    @Test("A technique minted without a level is Beginner and not a single")
    func defaultLevel() throws {
        let info = TechniqueInfo(id: "test.plain", difficulty: 65)
        #expect(info.level == .easy)
        #expect(info.isSingle == false)
        // Infos encoded before 2.0 carry neither key
        let data = Data(#"{"id":"test.old","difficulty":30,"scorePoints":20}"#.utf8)
        let decoded = try JSONDecoder().decode(TechniqueInfo.self, from: data)
        #expect(decoded.level == .easy)
        #expect(decoded.isSingle == false)
        #expect(decoded.scorePoints == 20)
    }

    @Test("Levels order Beginner to Master, then Custom")
    func levelOrder() {
        let levels = PuzzleDifficulty.Level.allCases
        #expect(levels == [.easy, .medium, .hard, .expert, .professional, .custom])
        #expect(zip(levels, levels.dropFirst()).allSatisfy { $0 < $1 })
        #expect(max(PuzzleDifficulty.Level.easy, .hard) == .hard)
    }
}
