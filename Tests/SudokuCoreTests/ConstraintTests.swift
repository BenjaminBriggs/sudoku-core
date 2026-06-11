import Foundation
import Testing

@testable import SudokuCore

/// Test-only constraint: forbids one digit in one cell.
struct ForbidDigit: Constraint {
    static let typeID = "test.forbidDigit"
    let position: Puzzle.Index
    let digit: Int

    var cells: [Puzzle.Index] { [position] }

    func violations(in state: BoardState) -> [ConstraintViolation] {
        if state.grid[position.row][position.column] == digit {
            return [ConstraintViolation(constraintTypeID: Self.typeID, cells: [position])]
        }
        return []
    }

    func prune(candidates: inout PencilMarks, in state: BoardState) {
        candidates[position.row][position.column].remove(digit)
    }
}

struct ConstraintTests {

    init() {
        ConstraintRegistry.register(ForbidDigit.self)
    }

    @Test("AnyConstraint round-trips through JSON")
    func roundTrip() throws {
        let original = AnyConstraint(ForbidDigit(position: .init(row: 3, column: 4), digit: 7))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyConstraint.self, from: data)
        #expect(decoded == original)
        let constraint = decoded.base as? ForbidDigit
        #expect(constraint?.digit == 7)
        #expect(constraint?.position == Puzzle.Index(row: 3, column: 4))
    }

    @Test("Encoded form uses type/payload keys")
    func encodedShape() throws {
        let constraint = AnyConstraint(ForbidDigit(position: .init(row: 0, column: 0), digit: 1))
        let data = try JSONEncoder().encode(constraint)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["type"] as? String == "test.forbidDigit")
        #expect(object?["payload"] is [String: Any])
    }

    @Test("Decoding an unregistered type throws unknownType")
    func unknownType() throws {
        let json = Data(#"{"type":"nobody.registered.this","payload":{}}"#.utf8)
        #expect(throws: ConstraintDecodingError.self) {
            _ = try JSONDecoder().decode(AnyConstraint.self, from: json)
        }
    }

    @Test("Lenient decoding preserves unknown constraint types verbatim")
    func lenientDecodePreservesUnknown() throws {
        let json = Data(
            #"{"type":"future.thermometer","payload":{"cells":[{"row":1,"column":2}],"bulbFirst":true}}"#
            .utf8)

        let decoder = JSONDecoder()
        decoder.userInfo[AnyConstraint.lenientDecodingUserInfoKey] = true
        let constraint = try decoder.decode(AnyConstraint.self, from: json)

        let unknown = try #require(constraint.base as? UnknownConstraint)
        #expect(unknown.originalTypeID == "future.thermometer")
        // Inert: no cells, no violations, no pruning surface.
        #expect(unknown.cells.isEmpty)
        #expect(unknown.violations(in: BoardState.fromGrid(Puzzle.example().startingState)).isEmpty)

        // Round-trips byte-for-byte in structure: type key and payload survive.
        let reencoded = try JSONEncoder().encode(constraint)
        let original = try JSONSerialization.jsonObject(with: json) as? NSDictionary
        let roundTripped = try JSONSerialization.jsonObject(with: reencoded) as? NSDictionary
        #expect(roundTripped == original)
    }

    @Test("Strict decoding still throws for unknown types even after lenient use")
    func strictRemainsDefault() {
        let json = Data(#"{"type":"future.thermometer","payload":{}}"#.utf8)
        #expect(throws: ConstraintDecodingError.self) {
            _ = try JSONDecoder().decode(AnyConstraint.self, from: json)
        }
    }

    @Test("Equality and hashing reflect the wrapped value")
    func equality() {
        let a = AnyConstraint(ForbidDigit(position: .init(row: 1, column: 1), digit: 2))
        let b = AnyConstraint(ForbidDigit(position: .init(row: 1, column: 1), digit: 2))
        let c = AnyConstraint(ForbidDigit(position: .init(row: 1, column: 1), digit: 3))
        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }
}
