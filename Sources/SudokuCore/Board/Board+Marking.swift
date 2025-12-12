//
//  Board+Marking.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//
import Foundation

// MARK: - Cell Modification Methods

extension Board {
    /// Places a value in the specified cells, clearing any pencil marks.
    ///
    /// This is the primary method for entering numbers during gameplay. It automatically:
    /// - Saves the current state to the undo stack
    /// - Clears all pencil marks from the affected cells
    /// - Updates board validation
    /// - Checks for completed rows, columns, houses, and numbers
    ///
    /// Given cells (part of the initial puzzle) cannot be modified and are skipped.
    ///
    /// - Parameters:
    ///   - positions: Set of positions to mark. Empty positions are ignored.
    ///   - value: The value to place (1-9), or `nil` to clear the cells.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Place a 5 in the center cell
    /// let center = Puzzle.Index(row: 4, column: 4)
    /// board.mark(positions: [center], as: 5)
    ///
    /// // Clear multiple cells
    /// board.mark(positions: selectedCells, as: nil)
    /// ```
    public func mark(positions: Set<Puzzle.Index>, as value: Int?) {
        guard positions.isEmpty == false else { return }
        saveState()
        for position in positions where cell(at: position).isGiven == false {
            self.cells[position.linerIndex]
                .value = value
            self.cells[position.linerIndex]
                .ruledOutCandidates
                .removeAll()
            self.cells[position.linerIndex]
                .simplePencilMarks
                .removeAll()
            self.cells[position.linerIndex]
                .advancedPencilMarks
                .removeAll()
        }
        updateCellValidation()
        updateCompletedSets()
    }

    /// Clears cells, removing values, pencil marks, and background colors.
    ///
    /// This method completely resets cells to their empty state. Values are only
    /// cleared from non-given cells, but pencil marks and colors are cleared from all cells.
    ///
    /// - Parameter positions: Set of positions to clear.
    public func clearCell(at positions: Set<Puzzle.Index>) {
        guard positions.isEmpty == false else { return }
        saveState()
        for position in positions {
            if cell(at: position).isGiven == false {
                self.cells[position.linerIndex]
                    .value = nil
            }
            self.cells[position.linerIndex]
                .ruledOutCandidates
                .removeAll()
            self.cells[position.linerIndex]
                .simplePencilMarks
                .removeAll()
            self.cells[position.linerIndex]
                .advancedPencilMarks
                .removeAll()
            self.cells[position.linerIndex]
                .background = .clear
        }

        updateCellValidation()
        updateCompletedSets()
    }

    /// Toggles simple pencil marks in the specified cells.
    ///
    /// If all specified empty cells already contain the value in their simple pencil marks,
    /// the value is removed. Otherwise, the value is added to empty cells that don't have it.
    ///
    /// Cells with values are skipped.
    ///
    /// - Parameters:
    ///   - positions: Set of positions to modify.
    ///   - value: The candidate number (1-9) to toggle.
    public func pencil(positions: Set<Puzzle.Index>, as value: Int) {
        guard positions.isEmpty == false else { return }
        saveState()
        let remove = positions
            .map(cell(at:))
            .filter { $0.value == nil }
            .map(\.simplePencilMarks)
            .allSatisfy { $0.contains(value) }
        for position in positions where cell(at: position).value == nil {
            if remove {
                self.cells[position.linerIndex]
                    .simplePencilMarks
                    .remove(value)
            } else {
                self.cells[position.linerIndex]
                    .simplePencilMarks
                    .insert(value)
            }
        }
    }

    /// Toggles advanced pencil marks in the specified cells.
    ///
    /// Similar to ``pencil(positions:as:)``, but modifies advanced pencil marks
    /// instead of simple marks. Advanced marks are used by experienced players
    /// for sophisticated solving techniques.
    ///
    /// If all specified empty cells already contain the value in their advanced pencil marks,
    /// the value is removed. Otherwise, it's added.
    ///
    /// - Parameters:
    ///   - positions: Set of positions to modify.
    ///   - value: The candidate number (1-9) to toggle.
    public func advancedPencil(positions: Set<Puzzle.Index>, as value: Int) {
        guard positions.isEmpty == false else { return }
        saveState()
        let remove = positions
            .map(cell(at:))
            .filter { $0.value == nil }
            .map(\.advancedPencilMarks)
            .allSatisfy { $0.contains(value) }
        for position in positions where cell(at: position).value == nil {
            if remove {
                self.cells[position.linerIndex]
                    .advancedPencilMarks
                    .remove(value)
            } else {
                self.cells[position.linerIndex]
                    .advancedPencilMarks
                    .insert(value)
            }
        }
    }

    /// Toggles background color/highlighting for the specified cells.
    ///
    /// If all specified cells already have the given background, they are cleared
    /// to `.clear`. Otherwise, the specified background is applied.
    ///
    /// This is used for hint visualization and player-applied cell coloring.
    ///
    /// - Parameters:
    ///   - positions: Set of positions to color.
    ///   - value: The background color to apply.
    public func color(positions: Set<Puzzle.Index>, as value: Cell.Background) {
        guard positions.isEmpty == false else { return }
        let remove = positions
            .map(cell(at:))
            .map(\.background)
            .allSatisfy { $0 == value }
        for position in positions {
            if remove {
                self.cells[position.linerIndex]
                    .background = .clear
            } else {
                self.cells[position.linerIndex]
                    .background = value
            }
        }
        saveState()
    }

    /// Marks a candidate value as ruled out (eliminated) for the specified cells.
    ///
    /// Ruled-out candidates are removed from ``Cell/allowedValues`` even if they
    /// appear in ``Cell/validOptions``. This is used when solving logic determines
    /// a value cannot go in certain cells.
    ///
    /// This method also removes the value from any existing pencil marks.
    ///
    /// - Parameters:
    ///   - positions: Set of positions where the value should be ruled out.
    ///   - value: The candidate number (1-9) to eliminate.
    public func ruleOut(positions: Set<Puzzle.Index>, as value: Int) {
        guard positions.isEmpty == false else { return }
        saveState()
        for position in positions where cell(at: position).value == nil {
            self.cells[position.linerIndex]
                .ruledOutCandidates
                .insert(value)
            self.cells[position.linerIndex]
                .simplePencilMarks
                .remove(value)
            self.cells[position.linerIndex]
                .advancedPencilMarks
                .remove(value)
        }
    }

    /// Applies a hint to the board by executing all of its actions.
    ///
    /// This processes each action in the hint step (solving cells, adding pencil marks,
    /// ruling out candidates, or clearing cells) and updates validation afterward.
    ///
    /// The ``hintsUsed`` counter is automatically incremented.
    ///
    /// - Parameter hint: The hint step containing the actions to apply.
    public func apply(hint: HintStep) {
        hintsUsed += 1
        for action in hint.actions {
            switch action.action {
            case .clear:
                clearCell(at: [action.position])
            case .pencilIn(let value):
                pencil(
                    positions: [action.position],
                    as: value
                )
            case .ruleOut(let value):
                ruleOut(
                    positions: [action.position],
                    as: value
                )
            case .solveAs(let value):
                mark(
                    positions: [action.position],
                    as: value
                )
            }
        }
        updateCellValidation()
    }
}
