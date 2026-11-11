//
//  LookupTablesTests.swift
//  SudokuCore
//
import Testing
@testable import SudokuCore

@Suite("Lookup tables")
struct LookupTablesTests {
    /// The cells in a cell-set bitmask.
    private func cells(in mask: UInt128) -> Set<Puzzle.Index> {
        Set((0..<128).filter { mask & (1 << UInt128($0)) != 0 }.map { Puzzle.Index(row: $0 / 9, column: $0 % 9) })
    }

    @Test("Each cell's peer mask is its 20 neighbours")
    func peerMasks() {
        #expect(LookupTables.peerMasks.count == 81)
        for cell in 0..<81 {
            let neighbours = LookupTables.cellNeighbours[cell / 9][cell % 9]
            #expect(neighbours.count == 20)
            #expect(cells(in: LookupTables.peerMasks[cell]) == neighbours)
        }
    }

    @Test("Unit masks hold each unit's cells, in the order of all units")
    func unitMasks() {
        #expect(LookupTables.unitMasks.count == 27)
        for (unit, mask) in zip(SudokuUnit.allUnits, LookupTables.unitMasks) {
            #expect(cells(in: mask) == Set(unit.positions))
        }
        #expect(cells(in: LookupTables.allCellsMask) == Set(Puzzle.Index.allIndices))
    }

    @Test("Choices are the combinations of a list's indices, in the same order")
    func choices() {
        for count in 0...9 {
            let items = Array(0..<count)
            for k in 0...10 {
                #expect(LookupTables.choices(of: count, choose: k) == HintFinder.combinations(of: items, choose: k))
            }
        }
        #expect(LookupTables.choices(of: 9, choose: 4).count == 126)
    }
}
