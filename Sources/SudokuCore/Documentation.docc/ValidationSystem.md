# Validation System

Ensure puzzle quality and track player progress with SudokuCore's validation system.

## Overview

SudokuCore provides comprehensive validation for Sudoku puzzles and game states. The validation system checks for conflicts, verifies solution uniqueness, and tracks completion progress.

## Puzzle Validation

### Basic Validity

Check if a puzzle configuration is valid (no conflicts):

```swift
let startingState: [[Int]] = [
    // Your 9x9 grid
]

if SudokuValidator.isValid(startingState) {
    print("Puzzle has no conflicts")
} else {
    print("Puzzle contains invalid configuration")
}
```

### Solution Uniqueness

Verify a puzzle has exactly one solution:

```swift
if SudokuValidator.hasUniqueSolution(startingState) {
    print("Puzzle has a unique solution")
} else {
    print("Puzzle has multiple solutions or no solution")
}
```

### Complete Validation

Check both validity and uniqueness:

```swift
func validatePuzzle(_ puzzle: [[Int]]) -> (valid: Bool, unique: Bool) {
    let isValid = SudokuValidator.isValid(puzzle)
    let hasUniqueSolution = SudokuValidator.hasUniqueSolution(puzzle)

    return (isValid, hasUniqueSolution)
}

let (valid, unique) = validatePuzzle(startingState)

if valid && unique {
    print("Puzzle is valid and solvable")
}
```

## Board State Validation

### Checking for Conflicts

The ``Board`` automatically maintains validation state:

```swift
let board = Board(puzzle: puzzle)

board.mark(positions: [position], as: 5)

if board.isValid {
    print("No conflicts in current state")
} else {
    print("Current state has conflicts")
}
```

### Valid Options

Each cell knows which values are valid:

```swift
let cell = board.cell(at: position)

print("Valid options: \(cell.validOptions)")
// Output: "Valid options: [2, 5, 8]"

print("Ruled out: \(cell.ruledOutCandidates)")
// Output: "Ruled out: [3, 7]"

print("Allowed values: \(cell.allowedValues)")
// Output: "Allowed values: [2, 5, 8]" (validOptions - ruledOut)
```

### Solvability

Check if the current board state can lead to a solution:

```swift
if board.isSolvable {
    print("Puzzle is still solvable")
} else {
    print("Current state has made the puzzle unsolvable")
}
```

## Completion Tracking

### Overall Completion

Check if the puzzle is solved:

```swift
if board.isSolved {
    print("Puzzle complete!")
    print("Errors: \(board.incorrectMoves)")
    print("Hints used: \(board.hintsUsed)")
}
```

### Partial Completion

Track progress by unit:

```swift
// Completed rows
for row in board.completedRows {
    print("Row \(row + 1) is complete")
}

// Completed columns
for column in board.completedColumns {
    print("Column \(column + 1) is complete")
}

// Completed houses (3×3 boxes)
for house in board.completedHouses {
    print("House \(house + 1) is complete")
}

// Completed numbers (all 9 instances placed)
for number in board.completedNumbers {
    print("All \(number)s are placed correctly")
}
```

### Progress Percentage

Calculate completion percentage:

```swift
extension Board {
    var completionPercentage: Double {
        let filledCells = cells.filter { $0.value != nil }.count
        let givenCells = cells.filter { $0.isGiven }.count
        let totalToFill = 81.0

        return Double(filledCells) / totalToFill * 100
    }

    var progressPercentage: Double {
        let filledCells = cells.filter { $0.value != nil && !$0.isGiven }.count
        let totalToFill = cells.filter { !$0.isGiven }.count

        return Double(filledCells) / Double(totalToFill) * 100
    }
}

print("Overall: \(Int(board.completionPercentage))%")
print("Your progress: \(Int(board.progressPercentage))%")
```

## Error Detection

### Incorrect Moves

Track when players place incorrect values (requires solution):

```swift
let board = Board(puzzle: puzzle)

// This assumes puzzle has a solution
board.mark(positions: [position], as: 5)

if board.incorrectMoves > 0 {
    print("Player has made \(board.incorrectMoves) errors")
}
```

### Cell-Level Validation

Check individual cells:

```swift
let cell = board.cell(at: position)

if let correct = cell.correctAnswer, let value = cell.value {
    if value != correct {
        print("Cell has incorrect value")
    }
}
```

### Conflict Detection

Find which cells are causing conflicts:

```swift
extension Board {
    func conflictingCells() -> [(Puzzle.Index, Set<Int>)] {
        var conflicts: [(Puzzle.Index, Set<Int>)] = []

        for cell in cells {
            guard let value = cell.value else { continue }

            // Check row conflicts
            let rowCells = cells.filter {
                $0.position.row == cell.position.row &&
                $0.position != cell.position &&
                $0.value == value
            }

            if !rowCells.isEmpty {
                conflicts.append((cell.position, [value]))
            }

            // Similar for column and house...
        }

        return conflicts
    }
}
```

## Valid Candidate Calculation

### Understanding Valid Options

The board automatically calculates valid candidates:

```swift
// After any change, the board updates validOptions for all cells
board.mark(positions: [position], as: 5)

for cell in board.cells where cell.value == nil {
    // validOptions contains numbers that don't conflict
    // with the same row, column, or house
    print("\(cell.position): \(cell.validOptions)")
}
```

### Manual Calculation

Get valid candidates for a specific cell:

```swift
let options = SudokuValidator.validOptions(
    for: position,
    in: board.cells.solution
)

print("Valid candidates: \(options)")
```

## Validation During Generation

Ensure generated puzzles meet quality standards:

```swift
func generateQualityPuzzle(
    difficulty: PuzzleDifficulty.Level
) async -> Puzzle? {
    let generator = SudokuGenerator()

    for attempt in 0..<100 {
        let puzzle = await generator.generatePuzzle(
            difficulty: difficulty,
            emptyCells: 40...50
        )

        // Validate
        guard SudokuValidator.isValid(puzzle.startingState) else {
            continue
        }

        guard SudokuValidator.hasUniqueSolution(puzzle.startingState) else {
            continue
        }

        // Check minimum clues (typically 17+)
        let givenCount = puzzle.startingState.flatMap { $0 }.filter { $0 != 0 }.count
        guard givenCount >= 17 else {
            continue
        }

        return puzzle
    }

    return nil
}
```

## Auto-Pencil Mark Validation

When auto-pencil mode is enabled, marks are based on valid options:

```swift
board.autoPencilMode = true

// Pencil marks now automatically reflect validOptions
for cell in board.cells where cell.value == nil {
    print("\(cell.position): \(cell.simplePencilMarks)")
    // Matches validOptions for that cell
}
```

## Solution Verification

### Verify Complete Solution

Check if a filled grid is a valid Sudoku solution:

```swift
let solution: [[Int]] = [
    // Complete 9×9 grid with all values filled
]

if SudokuValidator.isCompleteAndValidSolution(solution) {
    print("Valid Sudoku solution")
}
```

### Partial Solution Checking

Verify partial progress against the known solution:

```swift
extension Board {
    func isCorrectSoFar() -> Bool {
        guard let solution = solution else { return true }

        for cell in cells {
            if let value = cell.value {
                let correct = solution[cell.position.row][cell.position.column]
                if value != correct {
                    return false
                }
            }
        }

        return true
    }
}
```

## Performance Considerations

### Validation Frequency

The board validates after every modification:

```swift
// Each of these triggers validation
board.mark(positions: [pos1], as: 5)  // Validates
board.mark(positions: [pos2], as: 7)  // Validates again
board.pencil(positions: [pos3], as: 4) // Validates again
```

For batch operations, use a single call:

```swift
// Better: Single validation
board.mark(positions: [pos1, pos2], as: 5)
```

### Caching Validation Results

Cache expensive checks:

```swift
class ValidationCache {
    private var lastBoardState: [[Int]]?
    private var lastValidationResult: Bool?

    func isValid(_ board: Board) -> Bool {
        let currentState = board.cells.solution

        if currentState == lastBoardState {
            return lastValidationResult ?? false
        }

        let result = SudokuValidator.isValid(currentState)
        lastBoardState = currentState
        lastValidationResult = result

        return result
    }
}
```

## Next Steps

- Learn about <doc:WorkingWithBoards> for board operations
- Explore <doc:GeneratingPuzzles> to create valid puzzles
- Read about <doc:DifficultyRating> for quality metrics
