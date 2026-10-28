//
//  Board+StateRestoration.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 25/02/2025.
//
import Foundation

public struct BoardRestoration: Sendable {
    public var currentState: [[Int]]
    public var simplePencilMarks: [[Set<Int>]]
    public var advancedPencilMarks: [[Set<Int>]]
    public var backgroundColors: [[Int]]
    public var ruledOutCandidates: [[Set<Int>]]
    public var undoStack: [Board.UndoStep]
    public var solution: [[Int]]
    public var hintsUsed: Int
    public var incorrectMoves: Int
    public var noteUpdates: Int
    public var elapsedTime: TimeInterval

    public init(
        currentState: [[Int]],
        simplePencilMarks: [[Set<Int>]],
        advancedPencilMarks: [[Set<Int>]],
        backgroundColors: [[Int]],
        ruledOutCandidates: [[Set<Int>]],
        undoStack: [Board.UndoStep],
        solution: [[Int]],
        hintsUsed: Int,
        incorrectMoves: Int,
        noteUpdates: Int = 0,
        elapsedTime: TimeInterval
    ) {
        self.currentState = currentState
        self.simplePencilMarks = simplePencilMarks
        self.advancedPencilMarks = advancedPencilMarks
        self.backgroundColors = backgroundColors
        self.ruledOutCandidates = ruledOutCandidates
        self.undoStack = undoStack
        self.solution = solution
        self.hintsUsed = hintsUsed
        self.incorrectMoves = incorrectMoves
        self.noteUpdates = noteUpdates
        self.elapsedTime = elapsedTime
    }
}

extension Board {
    public func restore(
        currentState: [[Int]],
        simplePencilMarks: [[Set<Int>]],
        advancedPencilMarks: [[Set<Int>]],
        backgroundColors: [[Int]],
        ruledOutCandidates: [[Set<Int>]],
        undoStack: [Board.UndoStep],
        solution: [[Int]],
        hintsUsed: Int,
        incorrectMoves: Int
    ) {
        restore(
            BoardRestoration(
                currentState: currentState,
                simplePencilMarks: simplePencilMarks,
                advancedPencilMarks: advancedPencilMarks,
                backgroundColors: backgroundColors,
                ruledOutCandidates: ruledOutCandidates,
                undoStack: undoStack,
                solution: solution,
                hintsUsed: hintsUsed,
                incorrectMoves: incorrectMoves,
                elapsedTime: 0
            )
        )
    }

    public func restore(_ restoration: BoardRestoration) {
        self.solution = restoration.solution
        self.undoStack = restoration.undoStack

        self.hintsUsed = restoration.hintsUsed
        self.incorrectMoves = restoration.incorrectMoves
        self.noteUpdates = restoration.noteUpdates

        for (row, columns) in restoration.currentState.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                if value != 0 {
                    self.cells[position.linerIndex].value = value
                } else if cell(at: position).isGiven == false {
                    self.cells[position.linerIndex].value = nil
                }
            }
        }
        for (row, columns) in restoration.simplePencilMarks.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                self.cells[position.linerIndex].simplePencilMarks = value
            }
        }
        for (row, columns) in restoration.advancedPencilMarks.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                self.cells[position.linerIndex].advancedPencilMarks = value
            }
        }
        for (row, columns) in restoration.ruledOutCandidates.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                self.cells[position.linerIndex].ruledOutCandidates = value
            }
        }
        for (row, columns) in restoration.backgroundColors.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                self.cells[position.linerIndex].background = .init(from: value)
            }
        }
        refreshDerivedState()
    }
}

extension Board {
    public func resetToInitialState() {
        restore(
            currentState: .empty(),
            simplePencilMarks: .empty(),
            advancedPencilMarks: .empty(),
            backgroundColors: .empty(),
            ruledOutCandidates: .empty(),
            undoStack: [],
            solution: self.solution ?? [],
            hintsUsed: 0,
            incorrectMoves: 0
        )
    }
}

extension Board {
    public var currentGrid: [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for cell in cells {
            grid[cell.position.row][cell.position.column] = cell.value ?? 0
        }
        return grid
    }

    public var startingGrid: [[Int]] {
        Array(0..<9).map { row in
            Array(0..<9).map { col in
                let pos = Puzzle.Index(
                    row: row,
                    column: col
                )
                let cell = self.cell(
                    at: pos
                )
                if cell.isGiven {
                    return cell.value ?? 0
                } else {
                    return 0
                }
            }
        }
    }

    public var simplePencilMarks: [[Set<Int>]] {
        Array(0..<9).map { row in
            Array(0..<9).map { col in
                self.cell(
                    at: Puzzle.Index(
                        row: row,
                        column: col
                    )
                ).simplePencilMarks
            }
        }
    }

    public var advancedPencilMarks: [[Set<Int>]] {
        Array(0..<9).map { row in
            Array(0..<9).map { col in
                self.cell(
                    at: Puzzle.Index(
                        row: row,
                        column: col
                    )
                ).advancedPencilMarks
            }
        }
    }

    public var ruledOutCandidates: [[Set<Int>]] {
        Array(0..<9).map { row in
            Array(0..<9).map { col in
                self.cell(
                    at: Puzzle.Index(
                        row: row,
                        column: col
                    )
                ).ruledOutCandidates
            }
        }
    }

    public var backgroundColors: [[Int]] {
        Array(0..<9).map { row in
            Array(0..<9).map { col in
                self.cell(
                    at: Puzzle.Index(
                        row: row,
                        column: col
                    )
                ).background.rawValue
            }
        }
    }
}
