# Generating Puzzles

Create Sudoku puzzles at various difficulty levels with guaranteed unique solutions.

## Overview

SudokuCore includes a powerful puzzle generator that creates well-formed Sudoku puzzles with unique solutions. You can control difficulty, the number of empty cells, and ensure puzzles are solvable using specific techniques.

## Basic Generation

### One-Call Creation with PuzzleCreator

``PuzzleCreator`` orchestrates the whole pipeline — generation, uniqueness validation, and difficulty rating — in one call. To target a specific difficulty level:

```swift
let puzzle = try await PuzzleCreator.createPuzzleWithDifficulty(.hard)

print("Created \(puzzle.difficulty.level) puzzle")
print("Difficulty score: \(puzzle.difficulty.score)")
```

It steers up to `maxAttempts` solutions (default 20) towards the level, returns the first that the calculator rates at it, and otherwise the closest match. It never returns a puzzle that needs guessing. If you already have a solution and starting grid, rate and assemble them with:

```swift
let puzzle = try await PuzzleCreator.createPuzzle(
    solution: solution,
    startingState: startingState
)
```

Prefer ``PuzzleCreator`` unless you need control over an individual pipeline stage — the sections below break the same pipeline into its parts.

### Steering Towards a Level

``SudokuGenerator/createPuzzle(level:symmetry:givens:from:maxRatings:bestEffort:)`` aims clue removal at a level instead of generating blind and filtering. It removes clues (whole orbits under a symmetry) to a minimal puzzle, binary-searches the removal order for where the rating enters the level and its tedium window and where it leaves either, picks a point between, and swaps clues to push a minimal puzzle that is still one level short. Puzzles that need guessing are never kept. Pass `givens` to bound the number of clues: only puzzles in the range are rated, so it costs nothing, and ``SudokuGenerator/steerPuzzle(level:symmetry:givens:from:maxRatings:bestEffort:)`` reports ``SteerMiss/givens`` when the range ruled the level out.

```swift
if let steered = SudokuGenerator.createPuzzle(level: .expert, symmetry: .rotational180) {
    print(steered.result.level, steered.ratings)
}
```

It returns `nil` when the level isn't reached within `maxRatings`; pass `bestEffort: true` for the closest puzzle instead, with `matchesLevel` false. ``PuzzleDifficulty/Level/tediumRange`` is the singles effort the generator aims for at each level (Beginner 150–300, the rest 250–450).

For quality rules, ``SudokuDifficultyCalculator/DifficultyResult`` measures `needsGuessing`, `hardestTechniqueCount` (steps using the hardest technique) and `hardestTechniqueAfterLastHardestStep` (the hardest technique still needed once the hardest step is done).

### Generate a Puzzle Step by Step

Create a starting grid and assemble a rated ``Puzzle`` manually:

```swift
let (solution, startingState) = await SudokuGenerator.generatePuzzle(
    targetsEmptyCells: 45...55
)

let info = try SudokuDifficultyCalculator.calculateDifficulty(for: startingState)
let puzzle = Puzzle(
    solution: solution,
    startingState: startingState,
    difficulty: info.puzzleDifficulty
)

print("Created \(puzzle.difficulty.level) puzzle")
print("Difficulty \(puzzle.difficulty.difficulty ?? 0), tedium \(puzzle.difficulty.tedium ?? 0)")
```

### Difficulty Levels

Puzzles are classified after rating with ``SudokuDifficultyCalculator``, by the hardest technique the solve needs:

- `.easy` (Beginner) - Singles only
- `.medium` (Intermediate) - Locked candidates, pairs, triples
- `.hard` (Advanced) - Quads, fish, W-Wing, single-digit patterns, unique rectangles
- `.expert` (Expert) - XY-Wing, XYZ-Wing, BUG+1, finned swordfish, 4-Y-Wing
- `.professional` (Master) - Finned jellyfish, 5- to 7-Y-Wings, or the solver had to guess

### Empty Cell Count

Control rough puzzle difficulty by varying empty cells (rating still uses techniques):

```swift
// Easier puzzles (fewer empty cells)
let easyGrid = await SudokuGenerator.createPuzzle(from: SolutionGenerator.generateRandomSolution(), targetEmpty: 35)

// Harder puzzles (more empty cells)
let hardGrid = await SudokuGenerator.createPuzzle(from: SolutionGenerator.generateRandomSolution(), targetEmpty: 60)
```

### Symmetric Clue Layouts

Hand-crafted puzzles usually place their clues symmetrically. Pass a ``Symmetry`` and the generator removes clues a whole orbit at a time — the 2 or 4 cells that map onto each other — so the layout keeps that symmetry while the puzzle stays unique:

```swift
let daily = try await PuzzleCreator.createPuzzleWithDifficulty(.hard, symmetry: .rotational180)

let grid = await SudokuGenerator.createPuzzle(
    from: SolutionGenerator.generateRandomSolution(),
    targetEmpty: 58,
    symmetry: .rotational90
)
```

Because orbits are removed whole, the result can stop up to an orbit short of `targetEmpty`. ``PuzzleCreator`` makes up for the coarser steps by removing further orbits (``SudokuGenerator/removingOrbit(from:symmetry:uniqueCheck:)``) while a candidate rates easier than the target. Symmetry is a convention, not a logic rule; `.none` (the default) leaves generation unchanged.

``Symmetry/orthogonal`` and ``Symmetry/diagonals`` combine two mirrors (both centre lines, or both diagonals), so their orbits are the up-to-4 cells either mirror reaches. A layout with one of them also has each mirror and `.rotational180`, and ``Symmetry/symmetries(of:)`` lists them all.

To find which symmetries an existing grid has, use ``Symmetry/symmetries(of:)``:

```swift
Symmetry.symmetries(of: puzzle.startingState)  // e.g. [.rotational180]
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
        let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
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
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: startingState)

print("\(info.level): difficulty \(info.difficulty), tedium \(info.tedium)")
print("SE rating: \(info.seRating ?? 0)")
print("Hardest technique: \(info.hardestTechnique ?? .hiddenSingle)")
print("Estimated time: \(info.estimatedTimeSeconds ?? 0)s")
```

### Level, Difficulty and Tedium

The level is the hardest technique's:

- **Beginner**: singles only
- **Intermediate**: locked candidates, pairs, triples
- **Advanced**: quads, fish, W-Wing, single-digit patterns, unique rectangles
- **Expert**: XY- and XYZ-Wings, BUG+1, finned swordfish, 4-Y-Wings
- **Master**: finned jellyfish, 5- to 7-Y-Wings, or needs guessing

The score sums HoDoKu's points over every step, split into difficulty (steps beyond singles) and tedium (singles). <doc:DifficultyRating> has the full tables, and covers the estimate of HoDoKu's own rating.

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

``PuzzleCreator/createPuzzleWithDifficulty(_:maxAttempts:symmetry:)`` already validates uniqueness and rates each candidate, so reach for it first. Write your own loop only when you need a constraint it doesn't offer — for example, a custom empty-cell range:

```swift
func generateValidatedPuzzle(
    targets: ClosedRange<Int> = 40...50,
    maxAttempts: Int = 10
) async -> Puzzle? {
    for _ in 0..<maxAttempts {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: targets)

        if Validator.hasUniqueSolution(starting) {
            if let info = try? SudokuDifficultyCalculator.calculateDifficulty(for: starting) {
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
                let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
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
        let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
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
func generatePuzzleWithTechnique(_ technique: TechniqueID) async -> Puzzle? {
    for _ in 0..<100 {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 45...55)
        guard let info = try? SudokuDifficultyCalculator.calculateDifficulty(for: starting) else { continue }
        let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)
        if puzzle.difficulty.hardestTechnique == technique { return puzzle }
    }
    return nil
}

// Generate a puzzle that requires X-Wing
let xWingPuzzle = await generatePuzzleWithTechnique(TechniqueInfo.xWing.id)
```

## Next Steps

- Learn about <doc:DifficultyRating> for detailed rating information
- Explore <doc:HintSystem> to understand solving techniques
- Read about <doc:ValidationSystem> for puzzle quality assurance
