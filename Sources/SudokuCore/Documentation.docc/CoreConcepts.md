# Core Concepts

Understand the fundamental concepts and architecture of SudokuCore.

## Overview

SudokuCore is built around a few key concepts that work together to provide a complete Sudoku experience. Understanding these concepts will help you use the package effectively.

## The Grid System

### Coordinate System

SudokuCore uses zero-based coordinates where ``Puzzle/Index`` represents a position in the 9×9 grid:

- **Rows**: 0 (top) to 8 (bottom)
- **Columns**: 0 (left) to 8 (right)

```swift
let topLeft = Puzzle.Index(row: 0, column: 0)
let center = Puzzle.Index(row: 4, column: 4)
let bottomRight = Puzzle.Index(row: 8, column: 8)
```

### Houses (3×3 Boxes)

The grid is divided into nine 3×3 houses (also called boxes or regions), numbered 0-8 in row-major order:

```
┌───┬───┬───┐
│ 0 │ 1 │ 2 │
├───┼───┼───┤
│ 3 │ 4 │ 5 │
├───┼───┼───┤
│ 6 │ 7 │ 8 │
└───┴───┴───┘
```

The house number for any position is calculated as:
```swift
let house = (row / 3) * 3 + (column / 3)
```

## Game State: The Board

The ``Board`` class is the heart of SudokuCore. It manages:

1. **81 Cells**: Each ``Board/Cell`` has a position, optional value, and pencil marks
2. **Validation**: Tracks which rows, columns, houses, and numbers are complete
3. **History**: Maintains undo/redo stack with complete state snapshots
4. **Statistics**: Counts incorrect moves, hints used, and note updates

### Observable State

Board uses Swift's `@Observable` macro, making it perfect for SwiftUI:

```swift
@Observable
final class GameViewModel {
    let board: Board

    init(puzzle: Puzzle) {
        self.board = Board(puzzle: puzzle)
    }
}

struct GameView: View {
    let viewModel: GameViewModel

    var body: some View {
        if viewModel.board.isSolved {
            Text("You win!")
        }
    }
}
```

## Cells and Values

### Given vs Player Cells

- **Given cells** (`isGiven = true`): Part of the initial puzzle, cannot be modified
- **Player cells** (`isGiven = false`): Empty or filled by the player

### Pencil Marks

Each cell supports two types of candidate tracking:

- **Simple pencil marks**: Basic candidate numbers (1-9)
- **Advanced pencil marks**: Additional tracking for advanced techniques

### Valid Options

The board automatically maintains ``Board/Cell/validOptions`` for each empty cell - the set of numbers that don't conflict with the same row, column, or house.

Players can also rule out specific candidates using ``Board/Cell/ruledOutCandidates``.

## Puzzles

A ``Puzzle`` represents a Sudoku puzzle with:

- **Starting state**: Initial configuration with given cells
- **Solution**: Complete solved grid
- **Difficulty**: Level and score information

Puzzles are immutable and can be shared, while boards are mutable game sessions.

## Difficulty Rating

SudokuCore uses industry-standard difficulty ratings:

### HoDoKu Rating

A cumulative score based on all techniques needed to solve:
- **Beginner (1-300)**: Basic singles
- **Intermediate (301-600)**: Pairs, triples, locked candidates
- **Advanced (601-1000)**: Wings, fish patterns
- **Expert (1001-1600)**: Complex chains
- **Master (1601+)**: Extreme techniques

See ``PuzzleDifficulty`` for complete details.

### Sudoku Explainer (SE) Rating

Rates the difficulty of the hardest technique required (not cumulative).

## State Management Flow

1. **Player Action** → Calls a board method (``Board/mark(positions:as:)``, etc.)
2. **Save State** → Current state saved to undo stack
3. **Update Cells** → Cell values/marks modified
4. **Validate** → Update ``Board/Cell/validOptions``, check conflicts
5. **Check Completion** → Update completed rows/columns/houses/numbers
6. **UI Updates** → SwiftUI views automatically refresh via `@Observable`

## Working with Multiple Puzzles

You can have multiple boards active simultaneously:

```swift
let easyBoard = Board(puzzle: easyPuzzle)
let hardBoard = Board(puzzle: hardPuzzle)

// Each maintains independent state
easyBoard.mark(positions: [pos1], as: 5)
hardBoard.mark(positions: [pos2], as: 7)
```

## Next Steps

- Learn about <doc:WorkingWithBoards> for practical board operations
- Explore <doc:HintSystem> to help players solve puzzles
- Read about <doc:GeneratingPuzzles> to create your own puzzle library
