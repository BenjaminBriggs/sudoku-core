# Generating Puzzles

Create Sudoku puzzles at various difficulty levels with guaranteed unique solutions.

## Overview

SudokuCore includes a powerful puzzle generator that creates well-formed Sudoku puzzles with unique solutions. You can control difficulty, the number of empty cells, and ensure puzzles are solvable using specific techniques.

## Basic Generation

### Generate a Puzzle

Create a puzzle at a specific difficulty:

```swift
let generator = SudokuGenerator()

let puzzle = await generator.generatePuzzle(
    difficulty: .medium,
    emptyCells: 45...55
)

print("Created \(puzzle.difficulty.level) puzzle")
print("Difficulty score: \(puzzle.difficulty.score)")
```

### Difficulty Levels

Available difficulty levels:

- `.easy` - Basic singles only
- `.medium` - Pairs, triples, locked candidates
- `.hard` - Fish patterns (X-Wing, Swordfish)
- `.expert` - Advanced patterns (Wings, chains)
- `.professional` - Extreme techniques

### Empty Cell Count

Control puzzle difficulty by specifying empty cell ranges:

```swift
// Easier puzzles (fewer empty cells)
let easy = await generator.generatePuzzle(
    difficulty: .easy,
    emptyCells: 35...45
)

// Harder puzzles (more empty cells)
let hard = await generator.generatePuzzle(
    difficulty: .hard,
    emptyCells: 50...60
)
```

## Advanced Generation

### Custom Solutions

Generate a puzzle from a specific solution:

```swift
// Generate a random solution
let solution = SolutionGenerator.generateRandomSolution()

// Create a puzzle from it
let puzzle = await generator.generatePuzzle(
    difficulty: .medium,
    emptyCells: 45...55,
    from: solution
)
```

### Batch Generation

Generate multiple puzzles efficiently:

```swift
func generatePuzzleSet(count: Int, difficulty: PuzzleDifficulty.Level) async -> [Puzzle] {
    var puzzles: [Puzzle] = []

    for _ in 0..<count {
        let puzzle = await generator.generatePuzzle(
            difficulty: difficulty,
            emptyCells: 40...50
        )
        puzzles.append(puzzle)
    }

    return puzzles
}

// Generate 100 medium puzzles
let puzzles = await generatePuzzleSet(count: 100, difficulty: .medium)
```

## Difficulty Calculation

### Understanding Ratings

The generator uses ``SudokuDifficultyCalculator`` to rate puzzles:

```swift
let calculator = SudokuDifficultyCalculator()

let difficulty = await calculator.calculateDifficulty(for: puzzle)

print("HoDoKu score: \(difficulty.hodokuRating ?? 0)")
print("SE rating: \(difficulty.seRating ?? 0)")
print("Hardest technique: \(difficulty.hardestTechnique)")
print("Estimated time: \(difficulty.estimatedTimeSeconds ?? 0)s")
```

### HoDoKu Rating System

Cumulative difficulty based on all techniques needed:

- **Beginner (1-300)**: Naked/hidden singles
- **Intermediate (301-600)**: Locked candidates, pairs, triples
- **Advanced (601-1000)**: Fish patterns, basic wings
- **Expert (1001-1600)**: Complex chains, advanced patterns
- **Master (1601+)**: Extreme techniques

### Sudoku Explainer Rating

Rates the hardest single technique required (not cumulative):

```swift
if let seRating = puzzle.difficulty.seRating {
    switch seRating {
    case 0..<3.0:
        print("Easy puzzle")
    case 3.0..<5.0:
        print("Medium puzzle")
    case 5.0..<7.0:
        print("Hard puzzle")
    default:
        print("Expert puzzle")
    }
}
```

## Validation

### Verify Generated Puzzles

Ensure puzzles have unique solutions:

```swift
let isValid = SudokuValidator.isValid(puzzle.startingState)
let hasUniqueSolution = SudokuValidator.hasUniqueSolution(puzzle.startingState)

if isValid && hasUniqueSolution {
    print("Puzzle is valid and has a unique solution")
}
```

### Custom Validation

Validate during generation:

```swift
func generateValidatedPuzzle(
    difficulty: PuzzleDifficulty.Level,
    maxAttempts: Int = 10
) async -> Puzzle? {
    let generator = SudokuGenerator()

    for _ in 0..<maxAttempts {
        let puzzle = await generator.generatePuzzle(
            difficulty: difficulty,
            emptyCells: 40...50
        )

        if SudokuValidator.hasUniqueSolution(puzzle.startingState) {
            return puzzle
        }
    }

    return nil
}
```

## Performance Optimization

### Parallel Generation

Generate multiple puzzles in parallel:

```swift
func generatePuzzlesConcurrently(count: Int) async -> [Puzzle] {
    await withTaskGroup(of: Puzzle.self) { group in
        let generator = SudokuGenerator()

        for _ in 0..<count {
            group.addTask {
                await generator.generatePuzzle(
                    difficulty: .medium,
                    emptyCells: 40...50
                )
            }
        }

        var puzzles: [Puzzle] = []
        for await puzzle in group {
            puzzles.append(puzzle)
        }
        return puzzles
    }
}
```

### Caching Solutions

Reuse solutions for faster generation:

```swift
class PuzzleFactory {
    private var solutionCache: [[[Int]]] = []

    init(cacheSize: Int = 10) {
        // Pre-generate solutions
        for _ in 0..<cacheSize {
            solutionCache.append(SolutionGenerator.generateRandomSolution())
        }
    }

    func generatePuzzle(difficulty: PuzzleDifficulty.Level) async -> Puzzle {
        let generator = SudokuGenerator()
        let solution = solutionCache.randomElement()!

        return await generator.generatePuzzle(
            difficulty: difficulty,
            emptyCells: 40...50,
            from: solution
        )
    }
}
```

## Puzzle Storage

### Export Format

Save puzzles in a compact string format:

```swift
extension Puzzle {
    var exportString: String {
        startingState.flatMap { $0.map(String.init) }.joined()
    }

    static func from(string: String, difficulty: PuzzleDifficulty) -> Puzzle? {
        guard string.count == 81 else { return nil }

        let cells = Solution.cells(from: string)
        // Would need to calculate solution...

        return Puzzle(
            solution: [], // Calculate or load
            startingState: cells,
            difficulty: difficulty
        )
    }
}
```

### JSON Storage

Store puzzle collections:

```swift
struct PuzzleCollection: Codable {
    let name: String
    let difficulty: PuzzleDifficulty.Level
    let puzzles: [Puzzle]
    let created: Date
}

// Save
let collection = PuzzleCollection(
    name: "Daily Medium",
    difficulty: .medium,
    puzzles: generatedPuzzles,
    created: Date()
)

let data = try JSONEncoder().encode(collection)
try data.write(to: fileURL)

// Load
let loadedData = try Data(contentsOf: fileURL)
let collection = try JSONDecoder().decode(PuzzleCollection.self, from: loadedData)
```

## Quality Control

### Technique Distribution

Ensure puzzles use desired techniques:

```swift
func generatePuzzleWithTechnique(
    _ technique: HintTechnique
) async -> Puzzle? {
    let generator = SudokuGenerator()

    for _ in 0..<100 {
        let puzzle = await generator.generatePuzzle(
            difficulty: .hard,
            emptyCells: 45...55
        )

        if puzzle.difficulty.hardestTechnique == technique {
            return puzzle
        }
    }

    return nil
}

// Generate a puzzle that requires X-Wing
let xWingPuzzle = await generatePuzzleWithTechnique(.xWing)
```

## Next Steps

- Learn about <doc:DifficultyRating> for detailed rating information
- Explore <doc:HintSystem> to understand solving techniques
- Read about <doc:ValidationSystem> for puzzle quality assurance
