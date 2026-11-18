# Hint System

Provide intelligent hints to help players solve puzzles using recognized Sudoku techniques.

## Overview

SudokuCore includes a comprehensive hint system that can identify solving techniques from basic singles to advanced patterns like X-Wing and W-Wing. The system finds the easiest applicable technique and returns the actions to apply plus a structured ``HintReasoning`` record of *why* the deduction holds. Human-facing explanation text is built from the reasoning outside core, in the app layer.

## Finding Hints

### Basic Usage

Find the easiest available hint for the current board state:

```swift
if let hint = HintFinder.firstHint(in: board.state) {
    print(hint.technique.id)      // e.g. hiddenSingle
    print(hint.debugDescription)  // "Hint(hiddenSingle, [Hint add 7 at (5,3)])"
}
```

`firstHint(in:using:)` defaults to ``ClassicTechniques/all``. Pass your own array to check specific techniques — or to add techniques the core doesn't ship:

```swift
let techniques: [any HintTechnique] = [
    NakedSingleTechnique(),
    HiddenSingleTechnique(),
    NakedSubsetTechnique(size: 2),
    FishTechnique(size: 2, finned: false),
]

if let hint = HintFinder.firstHint(in: board.state, using: techniques) {
    print(hint.technique.id)
}
```

### Applying Hints

Once you have a hint, apply it to the board:

```swift
if let hint = HintFinder.firstHint(in: board.state, using: techniques) {
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
7. **BUG+1** (75) - All cells bivalue but one; only when the puzzle has one solution
8. **X-Wing** (80) - Fish pattern with 2 cells per unit
9. **Unique Rectangle Type 1** (82) - Only when the puzzle has one solution
10. **Swordfish** (84) - Fish pattern with 3 cells per unit
11. **XY-Wing** (86) - Bivalue pivot and two bivalue wings
12. **XYZ-Wing** (88) - Three-candidate pivot and two wings
13. **Skyscraper** (89) - Two strong links in parallel lines joined by a weak link
14. **Two-String Kite** (90) - The same chain with one strong link in a row and one in a column
15. **Crane** (91) - The same chain with one strong link in a box
16. **Empty Rectangle** (92) - A box's candidates on one row and column, plus a strong link
17. **W-Wing** (95) - Two matching bivalue cells joined by a strong link
18. **Unique Rectangles** (97-101) - Types 2, 4, 5 and 3; only when the puzzle has one solution
19. **Jellyfish** (103) - Fish pattern with 4 cells per unit
20. **Finned X-Wing** (104) - An X-Wing with extra candidates, sashimi included
21. **4-Y-Wing** (105) - Four cells holding four digits, every digit but one restricted
22. **Finned Swordfish / Jellyfish** (106, 107) - Fish with extra candidates, sashimi included
23. **5- to 7-Y-Wing** (130-140) - n cells holding n digits, every digit but one restricted

Each technique's ``TechniqueInfo/level`` rises with this order: singles (1-2) are Beginner;
locked candidates, pairs and triples (3-5) Intermediate; quads to XYZ-Wing (6-12) Advanced;
the single-digit patterns and W-Wing (13-17) Expert; the harder unique rectangles to 4-Y-Wing
(18-21) Master; and finned Swordfish and Jellyfish and the 5- to 7-Y-Wings (22-23)
Grandmaster. BUG+1 comes before X-Wing and unique rectangle type 1 straight after it, where
SudokuWiki tries them; X-Wing, Swordfish, XY-Wing and XYZ-Wing come in the order players are
taught them. The finned fish come late, as in HoDoKu, Sudoku Explainer and SudokuWiki: almost
every Skyscraper is also a sashimi Finned X-Wing, and with the fish tried first a Skyscraper
would never be the hint.

The uniqueness techniques run only when ``BoardState/assumesUniqueSolution`` is `true`.
`Board` sets it when its givens have one solution, and ``SolvePathEmitter`` sets it the
same way, so hints and ratings agree.

Numbers in parentheses show relative difficulty values.

### Technique Details

Every technique is identified by a ``TechniqueInfo`` — a stable ``TechniqueID`` plus its solve-order rank and (for classic techniques) rating metadata:

```swift
let technique = TechniqueInfo.xWing
print(technique.id)          // xWing
print(technique.difficulty)  // 80
print(technique.seId)        // "X-Wing"
```

### Adding Your Own Techniques

``HintTechnique`` is a protocol: conform to it to add techniques without touching core, then pass them to ``HintFinder/firstHint(in:using:)`` alongside ``ClassicTechniques/all``. Variant modules do exactly this — the `SudokuKiller` target adds cage-based techniques the same way an app would add a custom classic one:

```swift
struct MyTechnique: HintTechnique {
    let info = TechniqueInfo(id: "myApp.myTechnique", difficulty: 65)

    func findHint(in state: BoardState) -> HintStep? {
        // Inspect state.grid / state.pencilMarks, return a HintStep or nil
        nil
    }
}

let hint = HintFinder.firstHint(
    in: board.state,
    using: ClassicTechniques.all + [MyTechnique()]
)
```

## Hint Structure

### Hint Step

A ``HintStep`` contains:

```swift
struct HintStep {
    let technique: TechniqueInfo  // Which technique applies
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
        case ruleIn(Int)         // Take back a ruled-out candidate
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
    case .ruleIn(let value):
        print("Make \(value) a candidate at \(pos) again")
    case .pencilIn(let value):
        print("Note \(value) as candidate at \(pos)")
    case .clear:
        print("Clear cell at \(pos)")
    }
}
```

## Detecting Player Mistakes

The `.validation` technique doesn't advance the solve — it finds what's wrong. It checks, in priority order: duplicate digits in a row, then a column, then a box, then (when the board has a solution) any filled cell that disagrees with it, and finally (again only with a solution) the first empty cell whose answer has been ruled out.

```swift
if let mistake = ValidationTechnique().findHint(in: board.state) {
    // A .clear for each offending cell, or one .ruleIn for a ruled-out answer
    for action in mistake.actions {
        print("Mistake at \(action.position)")
    }
    board.apply(hint: mistake)  // Clears the offending cells, or rules the answer back in
}
```

`.validation` has difficulty 0, so it sorts first in ``ClassicTechniques/all`` — when the board contains an error, ``HintFinder/firstHint(in:using:)`` returns the mistake before suggesting any solving technique. A player who asks for a hint on a broken board is told what to fix first.

A ruled-out answer matters because every technique reasons from ``BoardState/pencilMarks``, which a board builds as each cell's valid options minus its ruled-out candidates. With the answer missing, a technique can find a "naked single" that isn't the answer, or an elimination built on the false mark. Validation catches it when the answer is still a valid option but not a candidate, one cell per hint. A wrong number is reported first: it is the more basic mistake, and it can itself be what makes an answer invalid. Applying the hint calls ``Board/ruleIn(positions:as:)``, which takes back that one candidate and leaves the cell's other ruled-out candidates and pencil marks alone; the whole hint is one undo step.

The hint's reasoning tells the three kinds apart:

- **A clash** records the conflicting cells as a `.constraint` component, the unit as its only unit and, when the solution is known, which of the two duplicates is actually correct as the `.subject`.
- **A wrong number** has no `.constraint` component. Its `.subject` is the cell, carrying the correct value as the fact's `value`, which is also the focus digit.
- **A ruled-out answer** has no `.constraint` component either. Its `.subject` is the cell as it is, empty: no `value`, and the candidates it has left, which never include the answer. The focus digit is the answer that was ruled out.

## Parsing Board States from Strings

``BoardStateParser`` builds a ``BoardState`` from a string — useful for tests, imports, and sharing positions. It auto-detects the format:

```swift
// Plain 81-character grid (0 or . for empty)
let state = try BoardStateParser.parse("020005060890007003...")

// Sudoku Coach exports (SCv7_...) are detected automatically,
// including in-progress positions with pencil marks
let imported = try BoardStateParser.parse("SCv7_32_f2e6ajib18...")

if let format = BoardStateParser.detectFormat(input) {
    print(format)  // .gridString81, .sudokuCoach, .sudokuCoachProgress
}
```

Parsing failures throw ``BoardStateParseError``.

## Progressive Hint System

Implement a progressive hint system that starts with easier techniques:

```swift
class HintProvider {
    private let techniques: [[any HintTechnique]] = [
        // Level 1: Beginner
        [NakedSingleTechnique(), HiddenSingleTechnique()],

        // Level 2: Intermediate
        [LockedCandidatesTechnique(kind: .pointing), LockedCandidatesTechnique(kind: .claiming),
         NakedSubsetTechnique(size: 2), HiddenSubsetTechnique(size: 2),
         NakedSubsetTechnique(size: 3), HiddenSubsetTechnique(size: 3)],

        // Level 3: Advanced
        [FishTechnique(size: 2, finned: false), FishTechnique(size: 3, finned: false),
         XYWingTechnique(), XYZWingTechnique()],

        // Level 4: Expert
        [SkyscraperTechnique(), WWingTechnique()]
    ]

    func findHint(for board: Board, maxLevel: Int) -> HintStep? {
        for level in 0..<min(maxLevel, techniques.count) {
            let state = board.state
            if let hint = techniques[level]
                .compactMap({ $0.findHint(in: state) })
                .first {
                return hint
            }
        }
        return nil
    }
}
```

Each tier above is some of the techniques at one of the package's levels; ``ClassicTechniques/upTo(_:)`` gives every technique up to a level, in solve order.

## Hint Visualization

Use cell coloring to highlight hint components:

```swift
if let hint = HintFinder.firstHint(in: board.state, using: techniques) {
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
let hint = FishTechnique(size: 2, finned: true).findHint(in: board.state)!

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
let basicHint = HintFinder.firstHint(
    in: board.state,
    using: [NakedSingleTechnique(), HiddenSingleTechnique()]
)

// Slower: Check all techniques (the default set)
let advancedHint = HintFinder.firstHint(in: board.state)
```

### Caching

Consider caching hints if the board state hasn't changed:

```swift
class HintCache {
    private var cachedHint: HintStep?
    private var cachedBoardState: [[Int]]?

    func getHint(for board: Board, techniques: [any HintTechnique]) -> HintStep? {
        let currentState = board.cells.solution

        if currentState == cachedBoardState, let cached = cachedHint {
            return cached
        }

        let state = board.state
        cachedHint = HintFinder.firstHint(in: state, using: techniques)
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
    let allowed = ClassicTechniques.all.filter {
        $0.info.difficulty <= settings.maxDifficulty
    }
    guard let hint = HintFinder.firstHint(in: board.state, using: allowed)
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
- See <doc:ExtendingWithVariants> for variant rules, constraints, and variant techniques
