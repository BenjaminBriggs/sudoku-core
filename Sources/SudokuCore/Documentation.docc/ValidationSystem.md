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

if Validator.hasNoConflicts(in: startingState) {
    print("Puzzle has no conflicts")
} else {
    print("Puzzle contains invalid configuration")
}
```

### Solution Uniqueness

Verify a puzzle has exactly one solution:

```swift
if Validator.hasUniqueSolution(startingState) {
    print("Puzzle has a unique solution")
} else {
    print("Puzzle has multiple solutions or no solution")
}
```

### Complete Validation

Check both validity and uniqueness:

```swift
func validatePuzzle(_ puzzle: [[Int]]) -> (valid: Bool, unique: Bool) {
    let isValid = Validator.hasNoConflicts(in: puzzle)
    let hasUnique = Validator.hasUniqueSolution(puzzle)

    return (isValid, hasUnique)
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
let allOptions = Validator.validOptions(for: board.cells.solution)
let options = allOptions[position.row][position.column]
print("Valid candidates: \(options)")
```

## Solving Arbitrary Grids

``SudokuSolver`` is a constraint-propagation solver (arc consistency with domain splitting) for any grid — no human-style techniques involved. Use it when you need *a* solution rather than a rated solve path:

```swift
let (solution, callCount) = SudokuSolver.solve(grid: startingState)

if let solution {
    print("Solved in \(callCount) propagation calls")
} else {
    print("No solution exists")
}
```

`callCount` is a rough work measure — higher means more backtracking was needed. For uniqueness checking prefer ``Validator/hasUniqueSolution(_:)``, and for human-style difficulty use ``SudokuDifficultyCalculator`` (which falls back to `SudokuSolver` only when hint techniques can't finish a puzzle).

## Validation During Generation

Ensure generated puzzles meet quality standards:

```swift
func generateQualityPuzzle() async -> Puzzle? {
    for _ in 0..<100 {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 40...50)

        // Validate
        guard Validator.hasNoConflicts(in: starting) else { continue }
        guard Validator.hasUniqueSolution(starting) else { continue }

        // Check minimum clues (typically 17+)
        let givenCount = starting.flatMap { $0 }.filter { $0 != 0 }.count
        guard givenCount >= 17 else { continue }

        if let info = try? SudokuDifficultyCalculator.calculateDifficulty(for: starting) {
            return Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
        }
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

if (try? Validator.isCompleteAndValidSolution(solution)) == true {
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

        let result = Validator.hasNoConflicts(in: currentState)
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
