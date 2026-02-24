# Hint System

Provide intelligent hints to help players solve puzzles using recognized Sudoku techniques.

## Overview

SudokuCore includes a comprehensive hint system that can identify and explain solving techniques from basic singles to advanced patterns like X-Wing and Y-Wing. The system finds the easiest applicable technique and provides clear explanations.

## Finding Hints

### Basic Usage

Find the next available hint for the current board state:

```swift
let techniques: [HintTechnique] = [
    .nakedSingle,
    .hiddenSingle,
    .nakedPair,
    .xWing
]

if let hint = techniques.compactMap({ HintFinder.findHint(for: $0, in: board.state) }).first {
    print(hint.title)
    print(hint.description)
}
```

### Applying Hints

Once you have a hint, apply it to the board:

```swift
if let hint = techniques.compactMap({ HintFinder.findHint(for: $0, in: board.state) }).first {
    // Show the hint to the player first...

    // Then apply it
    board.apply(hint: hint)
    // Note: board.hintsUsed is automatically incremented
}
```

## Hint Techniques

### Difficulty Progression

Techniques are ordered from easiest to hardest:

1. **Naked Single** (10) - Only one candidate remaining in a cell
2. **Hidden Single** (20) - Value can only go in one place in a unit
3. **Locked Candidates** (40) - Pointing and claiming
4. **Naked/Hidden Pairs** (50) - Two cells share two candidates
5. **Naked/Hidden Triples** (60) - Three cells share three candidates
6. **Naked/Hidden Quads** (70) - Four cells share four candidates
7. **X-Wing** (80) - Fish pattern with 2 cells per unit
8. **Skyscraper** (90) - Special coloring pattern
9. **Swordfish** (90) - Fish pattern with 3 cells per unit
10. **Finned Fish** (85-105) - Fish with extra candidates
11. **Y-Wing/XY-Wing** (110) - Wing patterns
12. **XYZ-Wing** (120) - Three-cell wing pattern

Numbers in parentheses show relative difficulty values.

### Technique Details

Access technique information:

```swift
let technique = HintTechnique.xWing
print(technique.difficulty)  // 80
print(technique.seId)        // "X-Wing"
```

## Hint Structure

### Hint Step

A ``HintStep`` contains:

```swift
struct HintStep {
    let technique: HintTechnique  // Which technique applies
    let title: String             // Human-readable title
    let description: String       // Detailed explanation
    let actions: [HintAction]     // What to do
}
```

### Hint Actions

Each action specifies what to do with a cell:

```swift
enum HintAction {
    case clear                    // Clear the cell
    case pencilIn(Int)           // Add a pencil mark
    case ruleOut(Int)            // Eliminate a candidate
    case solveAs(Int)            // Place this value
}
```

Example:

```swift
for action in hint.actions {
    let pos = action.position
    switch action.action {
    case .solveAs(let value):
        print("Place \(value) at \(pos)")
    case .ruleOut(let value):
        print("Eliminate \(value) from \(pos)")
    case .pencilIn(let value):
        print("Note \(value) as candidate at \(pos)")
    case .clear:
        print("Clear cell at \(pos)")
    }
}
```

## Progressive Hint System

Implement a progressive hint system that starts with easier techniques:

```swift
class HintProvider {
    private let techniques: [[HintTechnique]] = [
        // Level 1: Basic
        [.nakedSingle, .hiddenSingle],

        // Level 2: Intermediate
        [.lockedCandidatesPointing, .lockedCandidatesClaiming],

        // Level 3: Advanced
        [.nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple],

        // Level 4: Expert
        [.xWing, .swordfish, .skyscraper],

        // Level 5: Master
        [.yWing, .xyWing, .xyzWing]
    ]

    func findHint(for board: Board, maxLevel: Int) -> HintStep? {
        for level in 0..<min(maxLevel, techniques.count) {
            let state = board.state
            if let hint = techniques[level]
                .compactMap({ HintFinder.findHint(for: $0, in: state) })
                .first {
                return hint
            }
        }
        return nil
    }
}
```

## Hint Visualization

Use cell coloring to highlight hint components:

```swift
if let hint = techniques.compactMap({ HintFinder.findHint(for: $0, in: board.state) }).first {
    // Color cells mentioned in the hint
    for action in hint.actions {
        switch action.action {
        case .solveAs:
            board.color(positions: [action.position], as: .green)
        case .ruleOut:
            board.color(positions: [action.position], as: .red)
        case .pencilIn:
            board.color(positions: [action.position], as: .blue)
        default:
            break
        }
    }
}
```

## Understanding Hint Descriptions

Hints include detailed explanations:

```swift
let hint = HintFinder.findHint(for: .nakedSingle, in: board.state)!

print(hint.title)
// "Naked Single"

print(hint.description)
// "The cell at (5,3) has only one possible candidate: 7.
//  All other values are eliminated by existing values in
//  row 5, column 3, or house 4."
```

## Performance Considerations

### Technique Selection

Finding complex hints (like fish patterns) is more expensive than basic singles:

```swift
// Fast: Check only basic techniques
let basicHint = [.nakedSingle, .hiddenSingle]
    .compactMap({ HintFinder.findHint(for: $0, in: board.state) })
    .first

// Slower: Check all advanced techniques
let advancedHint = HintTechnique.orderedCases
    .compactMap({ HintFinder.findHint(for: $0, in: board.state) })
    .first
```

### Caching

Consider caching hints if the board state hasn't changed:

```swift
class HintCache {
    private var cachedHint: HintStep?
    private var cachedBoardState: [[Int]]?

    func getHint(for board: Board, techniques: [HintTechnique]) -> HintStep? {
        let currentState = board.cells.solution

        if currentState == cachedBoardState, let cached = cachedHint {
            return cached
        }

        let state = board.state
        cachedHint = techniques.compactMap { HintFinder.findHint(for: $0, in: state) }.first
        cachedBoardState = currentState
        return cachedHint
    }
}
```

## Hint Preferences

Let players control hint behavior:

```swift
struct HintSettings {
    var autoApply: Bool = false           // Apply hints automatically
    var showExplanation: Bool = true      // Show detailed explanation
    var maxDifficulty: Int = 3            // Limit technique complexity
    var highlightCells: Bool = true       // Color relevant cells
}

func provideHint(for board: Board, settings: HintSettings) -> HintStep? {
    let hint = HintFinder.findHint(
        for: board,
        in: techniques[settings.maxDifficulty]
    )

    guard let hint else { return nil }

    if settings.highlightCells {
        // Color cells...
    }

    if settings.autoApply {
        board.apply(hint: hint)
    }

    return settings.showExplanation ? hint : nil
}
```

## Next Steps

- Learn about <doc:DifficultyRating> to understand how techniques affect difficulty
- Explore <doc:WorkingWithBoards> for more board operations
- Read about <doc:GeneratingPuzzles> to create puzzles requiring specific techniques
