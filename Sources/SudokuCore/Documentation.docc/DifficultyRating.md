# Difficulty Rating

Understand how SudokuCore calculates and uses puzzle difficulty ratings.

## Overview

SudokuCore uses industry-standard rating systems to measure puzzle difficulty objectively. Understanding these systems helps you generate puzzles at appropriate difficulty levels and provide accurate difficulty information to players.

## Rating Systems

### HoDoKu Rating (Cumulative)

The HoDoKu rating is a cumulative score that sums the points for every solving technique used:

```swift
let puzzle = await generator.generatePuzzle(difficulty: .medium)
print("HoDoKu score: \(puzzle.difficulty.score)")
// Example output: "HoDoKu score: 450"
```

#### Difficulty Levels

The ``PuzzleDifficulty`` documentation defines these ranges:

| Level | HoDoKu Range | Description |
|-------|--------------|-------------|
| Beginner | 1-300 | Primarily naked and hidden singles |
| Intermediate | 301-600 | Pairs, triples, locked candidates |
| Advanced | 601-1000 | X-Wing, Swordfish, basic wings |
| Expert | 1001-1600 | Complex chains, advanced patterns |
| Master | 1601-2000+ | Extreme techniques |

#### Point Values

Each technique contributes points to the cumulative score:

- **Naked Single**: 4 points
- **Hidden Single**: 20 points
- **Locked Candidates**: 40 points
- **Naked Pair**: 60 points
- **X-Wing**: 140 points
- **Swordfish**: 150 points
- **Y-Wing**: 160 points

See ``HintTechnique`` for complete technique information.

### Sudoku Explainer Rating (Peak Difficulty)

The SE rating represents the difficulty of the hardest technique required (not cumulative):

```swift
if let seRating = puzzle.difficulty.seRating {
    print("SE rating: \(seRating)")
    // Example: "SE rating: 4.2"
}
```

#### SE Rating Ranges

- **< 3.0**: Easy puzzles
- **3.0-5.0**: Medium puzzles
- **5.0-7.0**: Hard puzzles
- **7.0-9.0**: Very hard puzzles
- **> 9.0**: Extremely difficult puzzles

## Calculating Difficulty

### For Generated Puzzles

Puzzles from ``SudokuGenerator`` include difficulty information:

```swift
let puzzle = await generator.generatePuzzle(difficulty: .hard)

print("Level: \(puzzle.difficulty.level)")
print("HoDoKu: \(puzzle.difficulty.score)")
print("SE: \(puzzle.difficulty.seRating ?? 0)")
print("Hardest technique: \(puzzle.difficulty.hardestTechnique)")
```

### For Custom Puzzles

Calculate difficulty for any puzzle:

```swift
let calculator = SudokuDifficultyCalculator()

let startingState: [[Int]] = [
    // Your 9x9 puzzle grid
]

let difficulty = await calculator.calculateDifficulty(
    for: startingState
)

print("Calculated difficulty: \(difficulty.score)")
```

## Hardest Technique

The ``PuzzleDifficulty/hardestTechnique`` indicates the most advanced solving technique required:

```swift
let puzzle = await generator.generatePuzzle(difficulty: .hard)

switch puzzle.difficulty.hardestTechnique {
case .nakedSingle, .hiddenSingle:
    print("Beginner puzzle")
case .nakedPair, .hiddenPair, .nakedTriple:
    print("Intermediate puzzle")
case .xWing, .swordfish:
    print("Advanced puzzle - requires fish patterns")
case .yWing, .xyWing, .xyzWing:
    print("Expert puzzle - requires wing patterns")
default:
    print("Complex puzzle")
}
```

## Time Estimation

Puzzles can include estimated completion time:

```swift
if let estimatedTime = puzzle.difficulty.estimatedTimeSeconds {
    let minutes = estimatedTime / 60
    print("Estimated time: \(minutes) minutes")
}
```

Time estimates are based on:
- Difficulty score
- Number of empty cells
- Techniques required
- Historical solving data

## Custom Difficulty Levels

Create puzzles with specific difficulty characteristics:

```swift
func generatePuzzleWithConstraints() async -> Puzzle? {
    let generator = SudokuGenerator()

    for _ in 0..<50 {
        let puzzle = await generator.generatePuzzle(
            difficulty: .hard,
            emptyCells: 48...52
        )

        let score = puzzle.difficulty.score

        // Want a puzzle in the 700-800 range
        if score >= 700 && score <= 800 {
            return puzzle
        }
    }

    return nil
}
```

## Difficulty Progression

Design a progression system for players:

```swift
struct DifficultyProgression {
    let levels: [(name: String, scoreRange: ClosedRange<Int>)]

    init() {
        levels = [
            ("Novice", 1...150),
            ("Beginner", 151...300),
            ("Casual", 301...450),
            ("Intermediate", 451...600),
            ("Advanced", 601...800),
            ("Expert", 801...1200),
            ("Master", 1201...1600),
            ("Grandmaster", 1601...2000)
        ]
    }

    func level(for score: Int) -> String {
        levels.first { $0.scoreRange.contains(score) }?.name ?? "Custom"
    }
}

let progression = DifficultyProgression()
print(progression.level(for: puzzle.difficulty.score))
```

## Rating Components

### Technique-Based Rating

The cumulative score reflects all techniques used:

```swift
// A puzzle might use:
// - 15 naked singles (15 × 4 = 60)
// - 8 hidden singles (8 × 20 = 160)
// - 3 naked pairs (3 × 60 = 180)
// - 1 X-Wing (1 × 140 = 140)
// Total HoDoKu score = 540 (Intermediate)
```

### Empty Cell Influence

More empty cells generally increase difficulty, but technique requirements matter more:

```swift
// 40 empty cells + complex techniques = harder than
// 55 empty cells + only basic techniques
```

## Player Performance vs. Puzzle Difficulty

Distinguish between puzzle difficulty (intrinsic) and player performance:

```swift
// Intrinsic difficulty (from puzzle)
let puzzleDifficulty = puzzle.difficulty.score

// Player performance (from board)
let playerErrors = board.incorrectMoves
let hintsUsed = board.hintsUsed
let timeSpent = Date().timeIntervalSince(startTime)

// Performance score (custom calculation)
let performanceScore = calculatePerformanceScore(
    difficulty: puzzleDifficulty,
    errors: playerErrors,
    hints: hintsUsed,
    time: timeSpent
)
```

## Validating Difficulty

Ensure generated puzzles match expected difficulty:

```swift
func validateDifficulty(
    puzzle: Puzzle,
    expectedLevel: PuzzleDifficulty.Level
) -> Bool {
    let actualLevel = puzzle.difficulty.level

    // Allow one level of variance
    let allowedLevels: Set<PuzzleDifficulty.Level> = [
        expectedLevel,
        // Add adjacent levels if they exist
    ]

    return allowedLevels.contains(actualLevel)
}
```

## Advanced Topics

### Technique Distribution

Analyze which techniques a puzzle requires:

```swift
func analyzeTechniques(for puzzle: Puzzle) async -> [HintTechnique: Int] {
    var techniqueCounts: [HintTechnique: Int] = [:]

    let board = Board(puzzle: puzzle)

    while !board.isSolved {
        guard let hint = HintFinder.findHint(
            for: board,
            in: HintTechnique.allCases
        ) else { break }

        techniqueCounts[hint.technique, default: 0] += 1
        board.apply(hint: hint)
    }

    return techniqueCounts
}
```

### Difficulty Calibration

Collect data to calibrate difficulty ratings:

```swift
struct SolveData: Codable {
    let puzzleId: String
    let difficulty: PuzzleDifficulty
    let solveTime: TimeInterval
    let hintsUsed: Int
    let errors: Int
    let completed: Bool
}

// Use collected data to adjust difficulty estimates
```

## Next Steps

- Learn about <doc:GeneratingPuzzles> to create puzzles at specific difficulties
- Explore <doc:HintSystem> to understand solving techniques
- Read about <doc:ValidationSystem> to ensure puzzle quality
