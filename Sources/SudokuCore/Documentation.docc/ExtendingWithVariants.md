# Extending with Variants

Add new rules and solving techniques — from killer sudoku to one-off bespoke puzzles — without changing SudokuCore.

## Overview

SudokuCore's extension surface is two protocols. A **``Constraint``** is an additive rule layered on top of the classic 9×9 rules: it reports violations and prunes candidates. A **``HintTechnique``** finds hints. A "variant" is not a concept the core knows about — killer sudoku is just a cage constraint plus two techniques, and a hand-crafted bespoke puzzle is whatever constraints you can encode plus a presentation payload for everything you can't.

Variants are additive only: the 9×9 grid and the classic row/column/house rules always apply. The package does not generate or rate variant puzzles — variant puzzles arrive as data.

## Writing a Constraint

Conform to ``Constraint``:

```swift
import SudokuCore

/// All digits along the thermometer strictly increase from the bulb.
struct Thermometer: Constraint {
    static let typeID = "myApp.thermometer"   // stable forever once shipped

    let cells: [Puzzle.Index]                 // bulb first

    func violations(in state: BoardState) -> [ConstraintViolation] {
        var previous = 0
        for cell in cells {
            let value = state.grid[cell.row][cell.column]
            guard value != 0 else { previous = previous + 1; continue }
            if value <= previous {
                return [ConstraintViolation(constraintTypeID: Self.typeID, cells: cells)]
            }
            previous = value
        }
        return []
    }

    func prune(candidates: inout PencilMarks, in state: BoardState) {
        // Remove digits that cannot appear given the increasing sequence…
    }
}
```

The contract, enforced by the engine:

- **Pruning is removals-only, scoped to your declared `cells`.** Mutations to other cells and any *added* candidates are ignored.
- **Pruning runs repeatedly to a fixpoint.** Each pass rebuilds `state` from the current candidates, so eliminations made by other constraints become visible to you on later passes. Don't cache state across calls.
- **Report definite breaches only.** A violation should mean the rule is broken or unsatisfiable, not "might go wrong". If your rule becomes unsatisfiable, report a violation rather than pruning cells to an empty candidate set.
- `cells` must be inside the 9×9 grid — ``AnyConstraint`` traps out-of-range indices at wrap time.

## Registration — before any decoding

> Important: ``Puzzle`` decoding **throws** for any constraint type that has not been registered. Register every constraint type you ship at app startup, before any puzzle is decoded:

```swift
ConstraintRegistry.register(Thermometer.self)
KillerSudoku.register()   // variant modules expose a register() entry point
```

Constraints encode as `{"type": "<typeID>", "payload": { …your Codable fields… }}` inside the puzzle's `constraints` array. The `typeID` is the wire contract: never change it once puzzles have shipped.

For forward compatibility — decoding data authored by a *newer* client that has constraint types you don't know — opt into lenient decoding:

```swift
let decoder = JSONDecoder()
decoder.userInfo[AnyConstraint.lenientDecodingUserInfoKey] = true
```

Unknown types then decode as inert ``UnknownConstraint``s: they enforce nothing, but re-encode with their original type key and payload verbatim, so nothing is lost on a round-trip.

## Building a variant puzzle

```swift
let puzzle = Puzzle(
    solution: solution,
    startingState: starting,
    difficulty: PuzzleDifficulty(level: .custom, hardestTechnique: "killer.cageCombinations", score: 0),
    constraints: [AnyConstraint(KillerCage(cells: cageCells, sum: 17))],
    presentation: PuzzlePresentation(
        overlaySVG: cageOutlineSVG,
        rulesText: "Digits in cages sum to the small number; no repeats in a cage."
    )
)
let board = Board(puzzle: puzzle)   // pruning + violations work automatically
```

`Board` applies constraint pruning to every cell's `validOptions` and surfaces breaches in `Board/constraintViolations` — each violation carries the offending cells and the index of its source constraint in `constraints`.

### Bespoke one-off puzzles

``PuzzlePresentation`` is opaque to core: the app renders the overlay SVG and rules text however it likes. Rules you can't (or don't want to) encode as constraints are still enforced two ways: entries are checked against the known `solution`, and the `.validation` hint reports cells that disagree with it. Encode what's easy, present the rest.

## Variant techniques

Variant solving techniques are ordinary ``HintTechnique`` conformers (see <doc:HintSystem>) that read the puzzle's constraints from ``BoardState/constraints``:

```swift
let killers = board.state.constraints.compactMap { $0.base as? KillerCage }
```

Combine technique sets by concatenation — ``HintFinder/firstHint(in:using:)`` orders them by difficulty:

```swift
let hint = HintFinder.firstHint(
    in: board.state,
    using: ClassicTechniques.all + KillerSudoku.techniques
)
```

Namespace your ``TechniqueID``s with a module prefix (`killer.cageLastCell`, `myApp.thermoSweep`) — bare camel-case ids are reserved for the classic techniques, and collisions silently shadow built-ins in id-based lookups. Leave the SE/HoDoKu rating fields of ``TechniqueInfo`` nil: the package does not rate variant puzzles.

## The killer module as a template

The `SudokuKiller` library target is the reference implementation, structured the way any variant module should be:

- `KillerCage` — the ``Constraint`` (violations from duplicate digits, wrong complete sums, and infeasible remainders; pruning from sum combinations)
- `CageLastCell`, `CageCombinations` — the techniques
- `KillerSudoku.register()` / `KillerSudoku.techniques` — the module entry points

## Next Steps

- <doc:HintSystem> for the technique protocol and hint structure
- <doc:WorkingWithBoards> for board state and validation
