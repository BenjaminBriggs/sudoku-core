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
        recordingUndo {
            for position in positions where cell(at: position).isGiven == false {
                var cell = self.cells[position.linerIndex]
                cell.value = value
                cell.ruledOutCandidates.removeAll()
                cell.simplePencilMarks.removeAll()
                cell.advancedPencilMarks.removeAll()
                self.cells[position.linerIndex] = cell
            }
            refreshDerivedState()
        }
    }

    /// Clears cells, removing values, pencil marks, and background colors.
    ///
    /// This method completely resets cells to their empty state. Values are only
    /// cleared from non-given cells, but pencil marks and colors are cleared from all cells.
    ///
    /// - Parameter positions: Set of positions to clear.
    public func clearCell(at positions: Set<Puzzle.Index>) {
        guard positions.isEmpty == false else { return }
        recordingUndo {
            for position in positions {
                var cell = self.cells[position.linerIndex]
                if cell.isGiven == false {
                    cell.value = nil
                }
                cell.ruledOutCandidates.removeAll()
                cell.simplePencilMarks.removeAll()
                cell.advancedPencilMarks.removeAll()
                cell.background = .clear
                self.cells[position.linerIndex] = cell
            }

            refreshDerivedState()
        }
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
        recordingUndo {
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
        recordingUndo {
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
        recordingUndo {
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
        }
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
        recordingUndo {
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
        saveState()
        isPerformingAtomicChange = true
        defer { isPerformingAtomicChange = false }
        for action in redirectingGivens(in: hint.actions) {
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

    /// Moves any `.clear` aimed at a given cell onto the player's cell that clashes with it.
    ///
    /// `HintFinder.checkValidity` works from `BoardState`, which carries values but not
    /// which cells are givens, and it names the *later-scanned* duplicate. When that is a
    /// given, the action cannot be carried out and the player's own mistake - the only cell
    /// they can change - is left standing.
    private func redirectingGivens(in actions: [HintAction]) -> [HintAction] {
        actions.map { action in
            guard case .clear = action.action else { return action }
            let target = cell(at: action.position)
            guard target.isGiven, let digit = target.value else { return action }
            let culprit = cells.first { candidate in
                candidate.isGiven == false
                    && candidate.value == digit
                    && (candidate.position.row == action.position.row
                        || candidate.position.column == action.position.column
                        || candidate.position.houseNumber == action.position.houseNumber)
            }
            guard let culprit else { return action }
            return HintAction(clearPosition: culprit.position)
        }
    }
}
