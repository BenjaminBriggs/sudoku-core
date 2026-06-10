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

    @Test("Classic constants preserve enum metadata")
    func classicMetadata() {
        #expect(TechniqueInfo.nakedSingle.difficulty == 10)
        #expect(TechniqueInfo.nakedSingle.hodokuPoints == 10)
        #expect(TechniqueInfo.nakedSingle.seStepValue == 1.2)
        #expect(TechniqueInfo.nakedSingle.seId == "Single")
        #expect(TechniqueInfo.validation.difficulty == 0)
        #expect(TechniqueInfo.unknown.difficulty == 9999)
        #expect(TechniqueInfo.xyzWing.hodokuPoints == 130)
        // 25 = 23 real techniques + validation + unknown, one per legacy enum case.
        #expect(TechniqueInfo.allClassic.count == 25)
    }
}
