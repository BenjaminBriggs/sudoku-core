//
//  KillerTechniques.swift
//  SudokuKiller
//
import Foundation
import SudokuCore

extension TechniqueInfo {
    /// Killer techniques carry no SE/HoDoKu metadata: the package does not rate variant puzzles.
    public static let killerCageLastCell = TechniqueInfo(
        id: "killer.cageLastCell", difficulty: 15)
    public static let killerCageCombinations = TechniqueInfo(
        id: "killer.cageCombinations", difficulty: 45)
}

extension BoardState {
    /// The killer cages active in this state, in constraint order.
    var killerCages: [KillerCage] {
        constraints.compactMap { $0.base as? KillerCage }
    }
}

/// Solves the last empty cell of a cage: its value is the cage sum minus the placed digits.
public struct CageLastCell: HintTechnique {
    public let info: TechniqueInfo = .killerCageLastCell
    public init() {}

    public func findHint(in state: BoardState) -> HintStep? {
        for cage in state.killerCages {
            var placedSum = 0
            var placedDigits: Set<Int> = []
            var filledCells: [Puzzle.Index] = []
            var emptyCells: [Puzzle.Index] = []
            for cell in cage.cells {
                let value = state.grid[cell.row][cell.column]
                if value == 0 {
                    emptyCells.append(cell)
                } else {
                    placedSum += value
                    placedDigits.insert(value)
                    filledCells.append(cell)
                }
            }
            guard emptyCells.count == 1, let target = emptyCells.first else { continue }

            let value = cage.sum - placedSum
            guard (1...9).contains(value),
                placedDigits.contains(value) == false,
                state.validOptions[target.row][target.column].contains(value)
            else { continue }

            let actions = [HintAction(position: target, solveAs: value)]
            return HintStep(
                actions: actions,
                technique: info,
                reasoning: HintReasoning(
                    focusDigits: [value],
                    components: [
                        HintComponent(
                            role: .subject,
                            cells: [CellFact(position: target, candidates: [value])]
                        ),
                        HintComponent(
                            role: .constraint,
                            cells: filledCells.map { CellFact($0, in: state) }
                        ),
                    ],
                    placements: [CandidateRef(position: target, digit: value)]
                )
            )
        }
        return nil
    }
}
