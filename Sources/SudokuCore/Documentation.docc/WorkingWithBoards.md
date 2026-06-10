# Working with Boards

Learn how to interact with the Board class for gameplay and puzzle solving.

## Overview

The ``Board`` class provides a rich API for managing game state, handling player input, and tracking progress. This guide covers common operations and patterns.

## Creating Boards

### From a Puzzle

The most common way to create a board:

```swift
let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 45...55)
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
let board = Board(puzzle: puzzle)
```

### From a String

For testing or loading saved games:

```swift
// 81-character string: 0 = empty, 1-9 = given values
let puzzleString = "800050040100007209600020030..."
let board = Board(difficulty: .medium, string: puzzleString)
```

### Empty Board

For custom puzzle creation:

```swift
let board = Board()  // All cells empty
```

## Placing Values

### Basic Number Entry

Use ``Board/mark(positions:as:)`` to place numbers:

```swift
let position = Puzzle.Index(row: 3, column: 5)
board.mark(positions: [position], as: 7)
```

### Multiple Cells

Mark several cells at once:

```swift
let positions: Set<Puzzle.Index> = [pos1, pos2, pos3]
board.mark(positions: positions, as: 9)
```

### Clearing Cells

Pass `nil` to clear values:

```swift
board.mark(positions: [position], as: nil)
```

Or use the dedicated clear method:

```swift
board.clearCell(at: [position])
```

## Pencil Marks

### Adding Simple Marks

Toggle pencil marks for candidate tracking:

```swift
// If the mark exists, it's removed; otherwise it's added
board.pencil(positions: [position], as: 5)
```

### Advanced Marks

For sophisticated solving techniques:

```swift
board.advancedPencil(positions: [position], as: 3)
```

### Auto Pencil Mode

Enable automatic pencil mark maintenance:

```swift
board.autoPencilMode = true  // Automatically updates all pencil marks
```

## Cell Highlighting

Color cells for visual hints or player organization:

```swift
board.color(positions: [position], as: .green)
board.color(positions: [position], as: .red)
board.color(positions: [position], as: .clear)  // Remove color
```

## Accessing Cells

### By Position

Get a specific cell:

```swift
let cell = board.cell(at: position)
print("Value: \(cell.value ?? 0)")
print("Is given: \(cell.isGiven)")
print("Valid options: \(cell.validOptions)")
```

### All Cells

The cells array is in row-major order:

```swift
for cell in board.cells {
    if let value = cell.value {
        print("Cell at \(cell.position) has value \(value)")
    }
}
```

### Filtering

Find cells matching criteria:

```swift
// All empty cells
let emptyCells = board.cells.filter { $0.value == nil }

// All cells with a specific value
let fives = board.cells.filter { $0.value == 5 }

// Cells in a specific row
let row0 = board.cells.filter { $0.position.row == 0 }
```

## Undo and Redo

### Basic Undo

Revert the last change (does nothing if there is no history):

```swift
board.undo()
```

### Undo to Checkpoint

Go back to a specific state:

```swift
// Save current state as a checkpoint
let checkpoint = board.makeCheckpoint()

// Make some moves...
board.mark(positions: [pos1], as: 5)
board.mark(positions: [pos2], as: 3)

// Undo back to the checkpoint
try board.undo(to: checkpoint)
```

`undo(to:)` throws ``UndoError/stepNotFound`` if the step is not in the undo history.

### Check Undo Availability

```swift
if board.canUndo {
    board.undo()
}
```

### Hints Are Atomic

Applying a hint with ``Board/apply(hint:)`` records a single undo step, no matter how many actions the hint contains — one `undo()` reverts the whole hint.

### Recovering from Mistakes

Every undo step records whether the board still matched the solution at that point. ``Board/recoverToLastCorrectState()`` walks the history backwards and rewinds to the most recent state where the player hadn't made an error:

```swift
if board.isSolvable == false {
    try board.recoverToLastCorrectState()
}
```

This is a heavier intervention than clearing a single bad cell — pair it with the `.validation` hint technique (see <doc:HintSystem>) for pinpointing individual mistakes.

## Validation and Completion

### Check Validity

See if the current board state has conflicts:

```swift
if board.isValid {
    print("No conflicts")
}
```

### Check Completion

```swift
if board.isSolved {
    print("Puzzle solved!")
    print("Incorrect moves: \(board.incorrectMoves)")
    print("Hints used: \(board.hintsUsed)")
}
```

### Completion Tracking

Monitor individual completion states:

```swift
// Which rows are complete?
for row in board.completedRows {
    print("Row \(row) is complete")
}

// Which numbers are fully placed?
for number in board.completedNumbers {
    print("All \(number)s are placed correctly")
}
```

## Statistics

Track player performance:

```swift
print("Incorrect moves: \(board.incorrectMoves)")
print("Hints used: \(board.hintsUsed)")
print("Note updates: \(board.noteUpdates)")
```

## State Persistence

### Saving an In-Progress Game

``BoardRestoration`` captures everything a saved game needs — values, both kinds of pencil marks, ruled-out candidates, cell colours, the undo history, and statistics. The board exposes matching snapshot properties to build one:

```swift
let saved = BoardRestoration(
    currentState: board.currentGrid,
    simplePencilMarks: board.simplePencilMarks,
    advancedPencilMarks: board.advancedPencilMarks,
    backgroundColors: board.backgroundColors,
    ruledOutCandidates: board.ruledOutCandidates,
    undoStack: board.undoStack,
    solution: board.solution ?? [],
    hintsUsed: board.hintsUsed,
    incorrectMoves: board.incorrectMoves,
    noteUpdates: board.noteUpdates,
    elapsedTime: elapsedTime
)
```

`BoardRestoration` itself is not `Codable`, so map it to your app's persistence model. ``UndoStep`` *is* `Codable`, so the undo history can be stored directly.

### Restoring

Recreate the board from the puzzle, then apply the saved state with ``Board/restore(_:)``:

```swift
let board = Board(puzzle: puzzle)
board.restore(saved)
```

Restoration reapplies all cell state and recomputes validation and completion tracking.

### Restarting

``Board/resetToInitialState()`` clears all player state — values, marks, colours, undo history, and statistics — back to the given cells:

```swift
board.resetToInitialState()
```

### Export Current State

Get the current grid as an array:

```swift
let currentState = board.currentGrid  // [[Int]] 9x9 array
```

### Export as String

For saving or sharing:

```swift
let stateString = board.cells.flatString(empty: "0")  // 81-character string
```

### Debug Output

Get a formatted view of the board:

```swift
print(board.cells.debugDescription)
// Output:
// [8,0,0, 0,0,5, 0,4,0],
// [1,0,0, 0,0,7, 2,0,9],
// ...
```

## Performance Considerations

### Batch Operations

When making multiple changes, batch them in a single method call when possible:

```swift
// Good: Single undo state
board.mark(positions: [pos1, pos2, pos3], as: 5)

// Less efficient: Three undo states
board.mark(positions: [pos1], as: 5)
board.mark(positions: [pos2], as: 5)
board.mark(positions: [pos3], as: 5)
```

### Observable Updates

Board is `@Observable`, so UI updates are automatic. Avoid manual notification:

```swift
// SwiftUI updates automatically
@Observable
class GameViewModel {
    let board: Board

    func makeMove() {
        board.mark(positions: [position], as: 5)
        // No need to manually notify - SwiftUI sees the change
    }
}
```

## Next Steps

- Learn about <doc:HintSystem> to provide solving assistance
- Explore <doc:GeneratingPuzzles> to create custom puzzles
- Read about <doc:DifficultyRating> to understand puzzle complexity
