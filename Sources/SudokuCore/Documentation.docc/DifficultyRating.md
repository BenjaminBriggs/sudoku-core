# Difficulty Rating

Understand how SudokuCore calculates and uses puzzle difficulty ratings.

## Overview

SudokuCore uses industry-standard rating systems to measure puzzle difficulty objectively. Understanding these systems helps you generate puzzles at appropriate difficulty levels and provide accurate difficulty information to players.

## Rating Systems

### HoDoKu Rating (Cumulative)

The HoDoKu rating is a cumulative score that sums the points for every solving technique used:

```swift
let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 45...55)
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
print("HoDoKu score: \(info.hodokuRating ?? 0)")
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

Each technique contributes a fixed number of points to the cumulative score, regardless of how many eliminations the step produces:

- **Naked Single**: 10 points
- **Hidden Single**: 12 points
- **Locked Candidates**: 20 points
- **Naked Pair**: 20 points
- **X-Wing**: 60 points
- **Swordfish**: 90 points
- **Y-Wing**: 100 points

See ``HintTechnique/hodokuPoints`` for the complete list.

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

Rate a generated starting grid and assemble a ``Puzzle``:

```swift
let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 50...55)
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)

print("Level: \(puzzle.difficulty.level)")
print("HoDoKu: \(puzzle.difficulty.score)")
print("SE: \(puzzle.difficulty.seRating ?? 0)")
print("Hardest technique: \(puzzle.difficulty.hardestTechnique)")
```

### For Custom Puzzles

Calculate difficulty for any puzzle:

```swift
let startingState: [[Int]] = [
    // Your 9x9 puzzle grid
]

let info = try SudokuDifficultyCalculator.calculateDifficulty(for: startingState)
print("Calculated difficulty: \(info.score)")
```

## Hardest Technique

The ``PuzzleDifficulty/hardestTechnique`` indicates the most advanced solving technique required:

```swift
let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 55...60)
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
let hardest = info.hardestTechnique ?? .hiddenSingle

switch hardest {
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
    for _ in 0..<50 {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 48...52)
        guard let info = try? SudokuDifficultyCalculator.calculateDifficulty(for: starting) else { continue }
        let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)

        // Want a puzzle in the 700-800 HoDoKu range
        if let hodoku = info.hodokuRating, (700...800).contains(hodoku) {
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
// - 30 naked singles (30 × 10 = 300)
// - 8 hidden singles (8 × 12 = 96)
// - 3 naked pairs (3 × 20 = 60)
// - 1 X-Wing (1 × 60 = 60)
// Total HoDoKu score = 516 (Intermediate)
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
        let state = board.state
        guard let hint = HintTechnique.orderedCases
            .compactMap({ HintFinder.findHint(for: $0, in: state) })
            .first else { break }

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
