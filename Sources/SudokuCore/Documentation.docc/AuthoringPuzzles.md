# Authoring Puzzles

Help a person set a puzzle forwards, the way hand setters work, with a guaranteed finish at every step.

## Overview

Hand setters don't remove clues from a solved grid. They choose the squares for clues first, often a symmetric pattern, and then give those squares digits one at a time. Each digit is chosen for the deduction it lets the solver make next, so the break-in and the hard step are designed rather than discovered. ``ForwardBuilder`` supports that way of working:

1. The setter marks a plan: the squares that will hold clues.
2. For any open square, ``ForwardBuilder/options(at:)`` lists the digits it can take, each with what logic does next: which technique the new deductions need, how many squares they fill, and how many planned squares they use up.
3. The setter takes a step. ``ForwardBuilder/recording(_:seed:budget:)`` records the option's technique, so the finished puzzle's solve has to take it; ``ForwardBuilder/placing(_:at:seed:budget:)`` places a clue without recording anything.
4. Finishing is taking ``ForwardBuilder/witness``.

### Why the builder keeps a witness

A clue placed later usually gives the solver a way around an earlier step: solved from scratch with every clue showing, a puzzle built through a Pointing and an X-Wing often needs only singles. So the builder always keeps a *witness*: a finished puzzle (one solution, solvable by the techniques up to the ceiling) that holds every clue placed so far and takes every recorded step, in order. A step is only taken when a witness survives it. A clue that agrees with the witness keeps it at no cost; any other clue searches for a new one.

```swift
let plan: Set<Puzzle.Index> = ... // the setter's squares
guard let start = await ForwardBuilder(plan: plan)?.withWitness(seed: 1, budget: .timed(.seconds(2))) else {
    // The plan has no fill within the budget.
    return
}
let options = await start.options()
if let step = options.first(where: { $0.technique == .lockedCandidatesPointing }),
   let next = await start.recording(step, seed: 2, budget: .timed(.seconds(1))) {
    print(next.recorded, next.witness!)
}
```

Builders are values: keep the earlier ones for undo.

To explain an option, ``ForwardBuilder/Option/techniqueHint`` gives its technique step as a ``HintStep`` with the reasoning the hint finder recorded, and ``ForwardBuilder/Option/state(before:)`` the grid and candidates the step works on. Every ``SolvePathEmitter/SolveStep`` keeps its reasoning the same way, through ``SolvePathEmitter/SolveStep/hint``.

### Recorded steps

A ``RecordedStep`` is the deduction itself: its technique, the digits it's about and the squares of its pattern and changes. With ``RecordedStep/Matching/deduction`` (the default), the finished puzzle's solve keeps the step only with the same technique on the same digits over overlapping squares, so another X-Wing elsewhere can't stand in for the setter's. ``RecordedStep/Matching/technique`` accepts any step of the technique.

### Saving and editing a build

``ForwardBuilder/snapshot`` is a ``ForwardBuilder/Snapshot`` to store; ``ForwardBuilder/init(restoring:)`` rebuilds from it and keeps the witness only if it still fits. ``ForwardBuilder/replacingPlan(_:)`` changes the plan: squares taken out keep the witness when it still fits, and squares added need a new one, so they get clues. ``ForwardBuilder/withNewWitness(seed:budget:)`` finds another ending, and ``ForwardBuilder/droppedSquares`` lists planned squares the witness leaves empty.

## Filling a plan

``PlanFiller`` finds the witness. Random digits almost never give a small plan one solution: below about 26 squares, nearly no random solution of the clues does. So the filler searches the clue digits instead. It changes one at a time, to a digit the square's row, column and box don't hold, and keeps the change while the number of solutions (``Validator/countSolutions(of:limit:)``, capped at 64) doesn't rise, until there is one. Walks race each other under a ``PlanFiller/Budget``; ``PlanFiller/Budget/moves(_:)`` runs one walk with a fixed seed, which always gives the same result.

Some plans can never be unique: two rows of a band, or two columns of a stack, with no planned square can swap in any solution. ``PlanFiller/swappableLines(in:)`` finds them instantly, so an app can say so while the setter marks squares.

When a plan has no fill, ``PlanFiller/squaresToAdd(_:symmetry:seed:budget:limit:)`` suggests orbits to add: for a closed plan, ones in the lines that can swap; otherwise ones covering the squares where ``PlanFiller/nearestFill(_:seed:budget:)``, the grid the search came closest with, still has a choice. Plans under ``PlanFiller/minimumSquares`` never fill.

When a step needs a new witness, the search starts from the previous one, a digit away, and first tries leaving out planned squares, since a witness that still holds every clue may only have lost a recorded step to a shortcut.

With ``PlanFiller/Request/relaxing`` set, a fill may leave out whole symmetric orbits of planned squares that hold no placed clue. Taking clues out never gives the solver a shortcut, so it brings back a recorded step the full plan skips.

## Solving with fewer techniques

``SolvePathEmitter/emit(from:using:maxIterations:)`` solves with only the techniques given, easiest first, and ``ClassicTechniques/upTo(_:)`` lists those up to a level: the path a solver who knows just those techniques takes. ``SolvePathEmitter/emit(continuingFrom:using:maxIterations:)`` carries a solve on from a ``BoardState``.

## Topics

### Building Forwards

- ``ForwardBuilder``
- ``ForwardBuilder/Option``
- ``ForwardBuilder/Configuration``
- ``ForwardBuilder/Snapshot``
- ``RecordedStep``

### Filling Plans

- ``PlanFiller``
- ``PlanFiller/Request``
- ``PlanFiller/Budget``
- ``PlanFiller/SwappableLines``
- ``PlanFiller/NearMiss``

### Counting and Sampling Solutions

- ``Validator/countSolutions(of:limit:)``
- ``Validator/hasSolution(_:nodeLimit:)``
- ``Validator/randomSolution(of:using:nodeLimit:)``
