# Generating Puzzles

Create Sudoku puzzles at various difficulty levels with guaranteed unique solutions.

## Overview

SudokuCore includes a powerful puzzle generator that creates well-formed Sudoku puzzles with unique solutions. You can control difficulty, the number of empty cells, and ensure puzzles are solvable using specific techniques.

## Basic Generation

### Generate a Puzzle

Create a starting grid and assemble a rated ``Puzzle``:

```swift
let (solution, startingState) = await SudokuGenerator.generatePuzzle(
    targetsEmptyCells: 45...55
)

let info = try await SudokuDifficultyCalculator.calculateDifficulty(for: startingState)
let puzzle = Puzzle(
    solution: solution,
    startingState: startingState,
    difficulty: info.puzzleDifficulty
)

print("Created \(puzzle.difficulty.level) puzzle")
print("Difficulty score: \(puzzle.difficulty.score)")
```

### Difficulty Levels

Puzzles are classified after rating with ``SudokuDifficultyCalculator``:

- `.easy` - Basic singles only
- `.medium` - Pairs, triples, locked candidates
- `.hard` - Fish patterns (X-Wing, Swordfish)
- `.expert` - Advanced patterns (Wings, chains)
- `.professional` - Extreme techniques

### Empty Cell Count

Control rough puzzle difficulty by varying empty cells (rating still uses techniques):

```swift
// Easier puzzles (fewer empty cells)
let easyGrid = await SudokuGenerator.createPuzzle(from: SolutionGenerator.generateRandomSolution(), targetEmpty: 35)

// Harder puzzles (more empty cells)
let hardGrid = await SudokuGenerator.createPuzzle(from: SolutionGenerator.generateRandomSolution(), targetEmpty: 60)
```

## Advanced Generation

### Custom Solutions

Generate a puzzle from a specific solution:

```swift
// Generate a random solution
let solution = SolutionGenerator.generateRandomSolution()

// Create a starting grid from it
let startingState = await SudokuGenerator.createPuzzle(
    from: solution,
    targetEmpty: 50
)
```

### Batch Generation

Generate multiple puzzles efficiently:

```swift
func generatePuzzleSet(count: Int, targets: ClosedRange<Int>) async throws -> [Puzzle] {
    var puzzles: [Puzzle] = []

    for _ in 0..<count {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: targets)
        let info = try await SudokuDifficultyCalculator.calculateDifficulty(for: starting)
        puzzles.append(Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty))
    }

    return puzzles
}

// Generate 100 puzzles near medium difficulty
let puzzles = try await generatePuzzleSet(count: 100, targets: 45...50)
```

## Difficulty Calculation

### Understanding Ratings

Use ``SudokuDifficultyCalculator`` to rate puzzles:

```swift
let info = try await SudokuDifficultyCalculator.calculateDifficulty(for: startingState)

print("HoDoKu score: \(info.hodokuRating ?? 0)")
print("SE rating: \(info.seRating ?? 0)")
print("Hardest technique: \(info.hardestTechnique ?? .hiddenSingle)")
print("Estimated time: \(info.estimatedTimeSeconds ?? 0)s")
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
let isValid = Validator.hasNoConflicts(in: puzzle.startingState)
let hasUniqueSolution = Validator.hasUniqueSolution(puzzle.startingState)

if isValid && hasUniqueSolution {
    print("Puzzle is valid and has a unique solution")
}
```

### Custom Validation

Validate during generation:

```swift
func generateValidatedPuzzle(
    targets: ClosedRange<Int> = 40...50,
    maxAttempts: Int = 10
) async -> Puzzle? {
    for _ in 0..<maxAttempts {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: targets)

        if Validator.hasUniqueSolution(starting) {
            if let info = try? await SudokuDifficultyCalculator.calculateDifficulty(for: starting) {
                return Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
            }
        }
    }

    return nil
}
```

## Performance Optimization

### Parallel Generation

Generate multiple puzzles in parallel:

```swift
func generatePuzzlesConcurrently(count: Int) async throws -> [Puzzle] {
    try await withThrowingTaskGroup(of: Puzzle.self) { group in
        for _ in 0..<count {
            group.addTask {
                let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 40...50)
                let info = try await SudokuDifficultyCalculator.calculateDifficulty(for: starting)
                return Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
            }
        }

        var puzzles: [Puzzle] = []
        for try await puzzle in group { puzzles.append(puzzle) }
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

    func generatePuzzle() async throws -> Puzzle {
        let solution = solutionCache.randomElement()!
        let starting = await SudokuGenerator.createPuzzle(from: solution, targetEmpty: 50)
        let info = try await SudokuDifficultyCalculator.calculateDifficulty(for: starting)
        return Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
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
func generatePuzzleWithTechnique(_ technique: HintTechnique) async -> Puzzle? {
    for _ in 0..<100 {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 45...55)
        guard let info = try? await SudokuDifficultyCalculator.calculateDifficulty(for: starting) else { continue }
        let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
        if puzzle.difficulty.hardestTechnique == technique { return puzzle }
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
