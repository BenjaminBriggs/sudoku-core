# Quick Start

Get started with SudokuCore in just a few lines of code.

## Overview

This guide will walk you through creating your first Sudoku game using SudokuCore, from generating a puzzle to handling player input.

## Creating Your First Game

### Step 1: Import the Package

First, add SudokuCore to your project and import it:

```swift
import SudokuCore
```

### Step 2: Generate a Puzzle

Use ``SudokuGenerator`` to create a puzzle at your desired difficulty:

```swift
let generator = SudokuGenerator()
let puzzle = await generator.generatePuzzle(
    difficulty: .medium,
    emptyCells: 45...55
)
```

### Step 3: Create a Board

Initialize a ``Board`` with your puzzle:

```swift
let board = Board(puzzle: puzzle)
```

### Step 4: Handle Player Input

Use the marking methods to process player actions:

```swift
// Place a number
let position = Puzzle.Index(row: 0, column: 0)
board.mark(positions: [position], as: 5)

// Add a pencil mark
board.pencil(positions: [position], as: 7)

// Undo a move
try board.undo()
```

### Step 5: Check for Completion

Monitor the board state to detect when the puzzle is solved:

```swift
if board.isSolved {
    print("Congratulations! Puzzle solved!")
}
```

## Working with Existing Puzzles

If you have a puzzle string (81 characters where 0 represents empty cells):

```swift
let puzzleString = "800050040100007209600020030..."
let board = Board(
    difficulty: .easy,
    string: puzzleString
)
```

## Using Hints

Help players when they're stuck:

```swift
// Find the next available hint
if let hint = HintFinder.findHint(for: board, in: [.nakedSingle, .hiddenSingle]) {
    // Show the hint to the player
    print(hint.title)
    print(hint.description)

    // Apply the hint if desired
    board.apply(hint: hint)
}
```

## Next Steps

- Learn about <doc:CoreConcepts> for a deeper understanding
- Explore <doc:WorkingWithBoards> for advanced board operations
- Check out <doc:GeneratingPuzzles> to create custom puzzle sets
