# Difficulty Rating

Understand how SudokuCore calculates and uses puzzle difficulty ratings.

## Overview

SudokuCore rates a puzzle by solving it the way a person would and scoring the techniques the solve needs. Understanding the ratings helps you generate puzzles at appropriate difficulty levels and provide accurate difficulty information to players.

## Rating Systems

### Level, Difficulty and Tedium

A puzzle's ``PuzzleDifficulty/level`` is the level of the hardest technique its solve needs, and nothing else. Its ``PuzzleDifficulty/score`` adds up a fixed number of points for every step of the solve, HoDoKu 2.6's step scores, and splits into ``PuzzleDifficulty/difficulty``, the points of the steps beyond singles, and ``PuzzleDifficulty/tedium``, the points of the singles (4 a naked, 14 a hidden one). ``ScoreCalculator`` computes all three.

```swift
let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 45...55)
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
print("\(info.level): difficulty \(info.difficulty), tedium \(info.tedium), score \(Int(info.score))")
// Example output: "Advanced: difficulty 150, tedium 294, score 444"
```

#### Difficulty Levels

Each technique carries its ``TechniqueInfo/level``, HoDoKu's level for the step; the puzzle takes the highest:

| Level | Hardest technique |
|-------|-------------------|
| ``PuzzleDifficulty/Level/easy`` (Beginner) | Naked and hidden singles |
| ``PuzzleDifficulty/Level/medium`` (Intermediate) | Locked candidates, pairs, triples |
| ``PuzzleDifficulty/Level/hard`` (Advanced) | Quads, fish, finned X-Wing, wings, skyscraper, two-string kite, crane, empty rectangle, unique rectangles, BUG+1 |
| ``PuzzleDifficulty/Level/expert`` (Expert) | Finned swordfish, finned jellyfish, 4- to 7-Y-Wings |
| ``PuzzleDifficulty/Level/professional`` (Master) | The solver had to guess |
| ``PuzzleDifficulty/Level/custom`` | A puzzle the player made, not rated |

This is where SudokuCore departs from HoDoKu, which also promotes a puzzle whose cumulative score passes a band. Here a long path of singles is a tedious Beginner puzzle, and one W-Wing after twenty singles is an Advanced one: no Beginner puzzle has a W-Wing, and the score ranks the player's effort, not the puzzle's level. Within a level, `difficulty` orders puzzles (one W-Wing is 150, a W-Wing and three pointings 300) and `tedium` says how long the singles will take. ``PuzzleDifficulty/Level`` is `Comparable` in this order.

#### Point Values

Each step adds its technique's ``TechniqueInfo/scorePoints``, HoDoKu 2.6's default step score, regardless of how many eliminations the step produces:

- **Naked Single**: 4 points
- **Hidden Single**: 14 points
- **Locked Candidates**: 50 points
- **Naked Pair**: 60 points
- **X-Wing**: 140 points
- **Swordfish**: 150 points
- **XY-Wing**: 160 points

Every classic ``TechniqueInfo`` constant carries its points, taken from ``RatingTables/HoDoKu/steps``. A stall, where the solver has to guess, is costed at 300 rather than HoDoKu's 20000-point give-up; the level is Master either way.

### HoDoKu Rating (Estimated)

``PuzzleDifficulty/hodokuRating`` and ``PuzzleDifficulty/hodokuLevel`` estimate the score and level HoDoKu itself gives the puzzle. They're for comparing with HoDoKu; the puzzle's level comes from its hardest technique, and HoDoKu's can be higher where its score passes a band.

``HoDoKuCalculator`` solves the puzzle trying techniques in HoDoKu's order, and adds HoDoKu 2.6's points for each step (``RatingTables/HoDoKu/steps``). As in HoDoKu, the level is the higher of two: the score's band, and the level of the hardest technique used. One finned Swordfish makes a puzzle ``HoDoKuLevel/unfair`` whatever its score.

| ``HoDoKuLevel`` | Score up to |
|-------|-------|
| ``HoDoKuLevel/easy`` | 800 |
| ``HoDoKuLevel/medium`` | 1000 |
| ``HoDoKuLevel/hard`` | 1600 |
| ``HoDoKuLevel/unfair`` | 1800 |
| ``HoDoKuLevel/extreme`` | no limit |

```swift
let info = try SudokuDifficultyCalculator.calculateDifficulty(for: starting)
if let rating = info.hodokuRating, let level = info.hodokuLevel {
    print("HoDoKu: \(rating) (\(level))")
}
```

It's an estimate. HoDoKu has techniques the hint finder doesn't, such as chains, Sue de Coq, Hidden Rectangles and Remote Pairs, and where it uses them its path, and so its rating, differ. Across the 3,745 shipped puzzles the hint finder solves, the estimate gave HoDoKu's level for 96% and its exact score for 58%; the misses are all hard or harder. The HoDoKu cross-check holds it to that (see `scripts/hodoku/README.md`). When the hint finder can't solve a puzzle there's no estimate, and both properties are nil: HoDoKu would go on with techniques the hint finder doesn't have.

Puzzles rated before SudokuCore 2.0 hold their own score in `hodokuRating` and have no `hodokuLevel`, `difficulty` or `tedium`.

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
print("Difficulty: \(puzzle.difficulty.difficulty ?? 0), tedium: \(puzzle.difficulty.tedium ?? 0)")
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
print("Calculated level: \(info.level), difficulty \(info.difficulty)")
```

## The Rating Pipeline

``SudokuDifficultyCalculator`` is a convenience over lower-level types you can use directly:

1. ``SolvePathEmitter`` simulates a human solve, applying the easiest applicable hint at each step and recording a technique-annotated path.
2. ``ScoreCalculator`` sums each step's ``TechniqueInfo/scorePoints`` over that path into difficulty and tedium, and takes the level from the hardest step.
3. ``SECalculator`` reports the hardest technique on the path (peak difficulty).
4. ``HoDoKuCalculator`` solves again in HoDoKu's order to estimate HoDoKu's rating.
5. ``TimeEstimator`` converts the score into a baseline time estimate.

Use them directly when you want the solve path itself or the ratings without re-solving:

```swift
let path = SolvePathEmitter.emit(from: startingState)

for step in path.steps {
    print("\(step.technique): \(step.placements) placements, \(step.eliminations) eliminations")
}

let score = ScoreCalculator.compute(from: path)
let se = SECalculator.compute(from: path)
print("\(score.level): difficulty \(score.difficulty), tedium \(score.tedium), SE \(se.rating)")
print(score.breakdown)  // technique id -> total points
```

The main path takes the easiest technique that applies at every step, which is not always the lightest way through. ``SolvePathEmitter/alternatives(from:maxIterations:)`` takes every other technique that applies at each step beyond singles and carries on easiest-first, returning the paths that solve, lightest first; ``HintFinder/hints(in:using:)`` gives one hint from every technique that applies to a state.

```swift
for path in SolvePathEmitter.alternatives(from: startingState) {
    let score = ScoreCalculator.compute(from: path)
    print("\(score.level): difficulty \(score.difficulty) over \(path.steps.count) steps")
}
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
case .xyWing, .xyzWing:
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

Time estimates are based on the score, so on the techniques required and the number of empty cells together.

## Custom Difficulty Levels

Create puzzles with specific difficulty characteristics:

```swift
func generatePuzzleWithConstraints() async -> Puzzle? {
    for _ in 0..<50 {
        let (solution, starting) = await SudokuGenerator.generatePuzzle(targetsEmptyCells: 48...52)
        guard let info = try? SudokuDifficultyCalculator.calculateDifficulty(for: starting) else { continue }
        let puzzle = Puzzle(solution: solution, startingState: starting, difficulty: info.puzzleDifficulty)

        // Want an Advanced puzzle with one hard step and few singles
        if info.level == .hard, info.difficulty <= 200, info.tedium <= 300 {
            return puzzle
        }
    }
    return nil
}
```

## Difficulty Progression

Design a progression system for players:

```swift
/// Splits each level in two by how much of its technique the puzzle asks for.
func tier(of puzzle: Puzzle) -> String {
    let level = puzzle.difficulty.level.debugDescription
    guard let difficulty = puzzle.difficulty.difficulty else { return level }
    switch puzzle.difficulty.level {
    case .easy: return level                       // singles only; tedium is the only spread
    case .medium: return difficulty <= 150 ? "Light \(level)" : "Heavy \(level)"
    default: return difficulty <= 400 ? "Light \(level)" : "Heavy \(level)"
    }
}
```

## Rating Components

### Technique-Based Rating

The cumulative score reflects all techniques used:

```swift
// A puzzle might use:
// - 30 naked singles (30 × 4 = 120)
// - 8 hidden singles (8 × 14 = 112)
// - 3 naked pairs (3 × 60 = 180)
// - 1 X-Wing (1 × 140 = 140)
// Total score = 552: difficulty 320, tedium 232, Advanced because of the X-Wing
```

### Empty Cell Influence

More empty cells raise the tedium, since every blank is a single; only the techniques set the level:

```swift
// 40 empty cells + an X-Wing = Advanced, tedium ~200
// 55 empty cells + only singles = Beginner, tedium ~300
```

## Player Performance vs. Puzzle Difficulty

Puzzle difficulty is intrinsic; player performance is how well a particular solve went. ``PerformanceScoreCalculator`` combines the two into a score (100–100,000) with a full breakdown of the applied multipliers and penalties:

```swift
let result = PerformanceScoreCalculator.calculateScore(
    baseDifficulty: puzzle.difficulty.score,        // difficulty + tedium
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
