# Hint System

Provide intelligent hints to help players solve puzzles using recognized Sudoku techniques.

## Overview

SudokuCore includes a comprehensive hint system that can identify solving techniques from basic singles to advanced patterns like X-Wing and W-Wing. The system finds the easiest applicable technique and returns the actions to apply plus a structured ``HintReasoning`` record of *why* the deduction holds. Human-facing explanation text is built from the reasoning outside core, in the app layer.

## Finding Hints

### Basic Usage

Find the easiest available hint for the current board state:

```swift
if let hint = HintFinder.firstHint(in: board.state) {
    print(hint.technique)         // e.g. .hiddenSingle
    print(hint.debugDescription)  // "Hint(Hidden Single, [Hint add 7 at (5,3)])"
}
```

Or check specific techniques:

```swift
let techniques: [HintTechnique] = [
    .nakedSingle,
    .hiddenSingle,
    .nakedPair,
    .xWing
]

if let hint = techniques.compactMap({ HintFinder.findHint(for: $0, in: board.state) }).first {
    print(hint.technique)
}
```

### Applying Hints

Once you have a hint, apply it to the board:

```swift
if let hint = techniques.compactMap({ HintFinder.findHint(for: $0, in: board.state) }).first {
    // Show the hint to the player first...

    // Then apply it
    board.apply(hint: hint)
    // board.hintsUsed is automatically incremented, and the whole hint —
    // however many actions it contains — is recorded as a single undo step.
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
    let actions: [HintAction]     // What to do
    let reasoning: HintReasoning  // Why the deduction holds
}
```

### Hint Actions

Each ``HintAction`` pairs a position with what to do there:

```swift
struct HintAction {
    let position: Puzzle.Index
    let action: ActionType

    enum ActionType {
        case solveAs(Int)        // Place this value
        case ruleOut(Int)        // Eliminate a candidate
        case pencilIn(Int)       // Add a pencil mark
        case clear               // Clear the cell
    }
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

## Hint Reasoning

Every hint carries a ``HintReasoning`` — a structured, `Codable` record of the deduction's premises. It captures the focus digit(s), the participating units, and labelled groups of cells (``HintComponent``) such as the fish base and cover, fins, wing pivots, or the cells being eliminated from.

```swift
let hint = HintFinder.findHint(for: .finnedXWing, in: board.state)!

print(hint.reasoning.focusDigits)     // [4]
print(hint.reasoning.units)           // The rows/columns forming the pattern

for component in hint.reasoning.components {
    print(component.role)             // .base, .cover, .fin, .eliminated, ...
    print(component.cells.map(\.position))
}
```

Use the reasoning to build hint presentation in your app — highlighting, narration, or seeding a generative explanation. Core deliberately contains no explanation copy.

### Validating Stored Hints

``HintReasoning/inconsistencies(in:)`` checks whether the recorded premises still hold against a board state, which tells you if a previously found hint is still applicable:

```swift
let problems = hint.reasoning.inconsistencies(in: board.state)
if problems.isEmpty {
    board.apply(hint: hint)
} else {
    // The board has changed since the hint was found — find a fresh one
    print(problems)
}
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
    var maxDifficulty: Int = 90           // Limit technique complexity
    var highlightCells: Bool = true       // Color relevant cells
}

func provideHint(for board: Board, settings: HintSettings) -> HintStep? {
    let allowed = HintTechnique.orderedCases.filter {
        $0.difficulty <= settings.maxDifficulty
    }
    let state = board.state
    guard let hint = allowed
        .compactMap({ HintFinder.findHint(for: $0, in: state) })
        .first
    else { return nil }

    if settings.highlightCells {
        // Color cells using hint.reasoning.components...
    }

    if settings.autoApply {
        board.apply(hint: hint)
    }

    return hint
}
```

## Next Steps

- Learn about <doc:DifficultyRating> to understand how techniques affect difficulty
- Explore <doc:WorkingWithBoards> for more board operations
- Read about <doc:GeneratingPuzzles> to create puzzles requiring specific techniques
