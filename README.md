# SudokuCore

The Sudoku engine for iOS and macOS: everything needed to play, generate, rate, and hint Sudoku puzzles.

## Scope

SudokuCore owns the logic of Sudoku — game state, puzzle generation, difficulty rating, validation, hint finding — and the utilities that support them.

## Features

- **Complete Game State Management**: Observable `Board` class with automatic validation and undo/redo
- **Puzzle Generation**: Create puzzles at any difficulty with guaranteed unique solutions
- **Intelligent Hints**: Find solving techniques from basic to advanced, each with a structured reasoning record
- **Difficulty Rating**: Industry-standard HoDoKu and Sudoku Explainer ratings
- **Validation**: Check puzzles for validity, solution uniqueness, and player progress
- **SwiftUI Ready**: Built with `@Observable` for seamless SwiftUI integration

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add SudokuCore as a local package dependency in your Xcode project:

1. File > Add Package Dependencies
2. Select "Add Local..."
3. Navigate to the `SudokuCore` directory
4. Click "Add Package"

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../SudokuCore")
]
```

## Quick Start

### Generate and Play a Puzzle

```swift
import SudokuCore

// Generate starting state (targetsEmptyCells controls rough difficulty)
let (solution, startingState) = await SudokuGenerator.generatePuzzle(
    targetsEmptyCells: 45...55
)

// Compute difficulty and assemble a Puzzle
let difficulty = try SudokuDifficultyCalculator
    .calculateDifficulty(for: startingState)
let puzzle = Puzzle(
    solution: solution,
    startingState: startingState,
    difficulty: difficulty.puzzleDifficulty
)

// Create a board for gameplay
let board = Board(puzzle: puzzle)

// Place a number
let position = Puzzle.Index(row: 0, column: 0)
board.mark(positions: [position], as: 5)

// Get the easiest available hint
if let hint = HintFinder.firstHint(in: board.state) {
    print("\(hint.technique): \(hint.actions)")
    board.apply(hint: hint)
}

// Undo
board.undo()

// Check completion
if board.isSolved {
    print("Puzzle solved! Errors: \(board.incorrectMoves), Hints: \(board.hintsUsed)")
}
```

### Load a Puzzle from String

```swift
// 81-character string (0 = empty, 1-9 = values)
let puzzleString = "800050040100007209600020030000004965750390021900650007590703610400000800203908000"
let board = Board(difficulty: .easy, string: puzzleString)
```

## Documentation

### Building Documentation

In Xcode:
1. Select Product > Build Documentation (⌃⌘⇧D)
2. Documentation opens in Xcode's Documentation Viewer

(The swift-docc-plugin is not a package dependency, so documentation builds through Xcode rather than the command line.)

### Topics Covered

- **Getting Started**: Quick start guide and core concepts
- **Game State**: Working with boards, cells, and validation
- **Hints**: Understanding and using the hint system
- **Puzzle Generation**: Creating puzzles at specific difficulties
- **Difficulty Rating**: HoDoKu and SE rating systems
- **Validation**: Ensuring puzzle quality and tracking progress

## Architecture

### Core Types

- **`Board`**: Main game state with 81 cells, validation, undo/redo
- **`Board.Cell`**: Individual cell with value, pencil marks, and validation state
- **`Puzzle`**: Immutable puzzle definition with starting state and solution
- **`Puzzle.Index`**: Zero-based (row, column) position in the 9×9 grid

### Modules

- **Board Management**: Game state, validation, undo/redo
- **Hints**: 18+ solving techniques from singles to advanced patterns
- **Generation**: Puzzle creation with difficulty targeting
- **Validation**: Conflict detection and solution verification
- **Rating**: HoDoKu cumulative and SE peak difficulty ratings

## Examples

### SwiftUI Integration

```swift
import SwiftUI
import SudokuCore

@Observable
final class GameViewModel {
    let board: Board

    init(puzzle: Puzzle) {
        self.board = Board(puzzle: puzzle)
    }

    func makeMove(at position: Puzzle.Index, value: Int) {
        board.mark(positions: [position], as: value)
    }
}

struct GameView: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack {
            if viewModel.board.isSolved {
                Text("You win!")
            } else {
                // Grid UI here
            }
        }
    }
}
```

### Progressive Hints

```swift
let techniques: [HintTechnique] = [
    .nakedSingle,
    .hiddenSingle,
    .nakedPair,
    .xWing
]

if let hint = techniques
    .compactMap({ HintFinder.findHint(for: $0, in: board.state) })
    .first {
    // Present the hint using its technique and reasoning
    showHint(hint)

    // Apply if player wants
    board.apply(hint: hint)
}
```

### Difficulty-Based Generation

`PuzzleCreator` runs the whole generate–validate–rate pipeline and targets a difficulty level:

```swift
func generatePuzzleSet(difficulty: PuzzleDifficulty.Level, count: Int) async throws -> [Puzzle] {
    var puzzles: [Puzzle] = []

    for _ in 0..<count {
        puzzles.append(try await PuzzleCreator.createPuzzleWithDifficulty(difficulty))
    }

    return puzzles
}
```

## Performance

- **Observable Updates**: Automatic SwiftUI updates via `@Observable`
- **Efficient Validation**: Incremental validation after each change
- **Parallel Generation**: Generate multiple puzzles concurrently
- **Optimised Algorithms**: Fast hint finding and difficulty calculation

## Contributing

When contributing please:

1. Follow existing documentation patterns
2. Add tests for new functionality
3. Update documentation for API changes
4. Ensure all tests pass before submitting

## Testing

Run tests in Xcode:

```bash
# Run all tests
swift test

# Run specific tests by name pattern
swift test --filter Board
```

## License

See the main project LICENSE file.

## Credits

- **Difficulty Rating**: Based on HoDoKu and Sudoku Explainer algorithms
- **Solving Techniques**: Implements standard Sudoku solving strategies
- **Architecture**: Designed for modern Swift with concurrency and observation
