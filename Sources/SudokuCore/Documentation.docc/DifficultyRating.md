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

See ``TechniqueInfo/hodokuPoints`` for the complete list.

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

## The Rating Pipeline

``SudokuDifficultyCalculator`` is a convenience over lower-level types you can use directly:

1. ``SolvePathEmitter`` simulates a human solve, applying the easiest applicable hint at each step and recording a technique-annotated path.
2. ``HoDoKuCalculator`` sums fixed per-technique points over that path (cumulative effort).
3. ``SECalculator`` reports the hardest technique on the path (peak difficulty).
4. ``TimeEstimator`` converts a HoDoKu rating into a baseline time estimate.

Use them directly when you want the solve path itself or both ratings without re-solving:

```swift
let path = SolvePathEmitter.emit(from: startingState)

for step in path.steps {
    print("\(step.technique): \(step.placements) placements, \(step.eliminations) eliminations")
}

let hodoku = HoDoKuCalculator.compute(from: path)
let se = SECalculator.compute(from: path)
print("HoDoKu \(hodoku.rating) (\(hodoku.classLabel)), SE \(se.rating)")
print(hodoku.breakdown)  // techniqueId -> total points
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

Puzzle difficulty is intrinsic; player performance is how well a particular solve went. ``PerformanceScoreCalculator`` combines the two into a score (100–100,000) with a full breakdown of the applied multipliers and penalties:

```swift
let result = PerformanceScoreCalculator.calculateScore(
    baseDifficulty: puzzle.difficulty.score,        // HoDoKu rating
    elapsedTime: Date().timeIntervalSince(startTime),
    hintsUsed: board.hintsUsed,
    errorCount: board.incorrectMoves,
    noteUpdates: board.noteUpdates
)

print("Score: \(result.score)")
print("Time multiplier: \(result.timeMultiplier)")
print("Hint penalty: \(result.hintPenalty)")
print("Perfect game: \(result.perfectBonus)")
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
func analyzeTechniques(for puzzle: Puzzle) async -> [TechniqueID: Int] {
    var techniqueCounts: [TechniqueID: Int] = [:]

    let board = Board(puzzle: puzzle)

    while !board.isSolved {
        guard let hint = HintFinder.firstHint(in: board.state) else { break }

        techniqueCounts[hint.technique.id, default: 0] += 1
        board.apply(hint: hint)
    }

    return techniqueCounts
}
```

### Personalized Time Estimates

``PersonalizedCalibrator`` learns how fast a particular player is relative to the baseline curve and adjusts time estimates accordingly. Feed it completed solves and ask it to predict:

```swift
var calibrator = PersonalizedCalibrator()

// After each completed puzzle, record the observed time
calibrator.update(rating: puzzle.difficulty.score, timeSeconds: 540)

// Predict the player's time for the next puzzle
let estimate = calibrator.predict(for: 800)
print("Expect ~\(estimate.seconds)s (\(estimate.rangeLower)–\(estimate.rangeUpper)s)")
print("Player speed factor: \(estimate.factor)")  // <1 faster, >1 slower than baseline
```

The calibrator keeps a bounded window of recent samples (default 100), clamps outliers, and widens its predicted range where the player's history is noisy. It is not `Codable` — store the raw (rating, time, date) observations in your player profile and replay them through ``PersonalizedCalibrator/update(rating:timeSeconds:at:)`` when restoring.

For a non-personalized baseline, use ``TimeEstimator/baselineSeconds(fromHoDoKu:)``.

## Next Steps

- Learn about <doc:GeneratingPuzzles> to create puzzles at specific difficulties
- Explore <doc:HintSystem> to understand solving techniques
- Read about <doc:ValidationSystem> to ensure puzzle quality
