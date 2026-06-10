# SudokuCore — Codebase Overview

Last updated: 2026-06-10 (commit 6954121)

SudokuCore is a Swift 6 package (iOS 18+ / macOS 15+) providing the complete Sudoku engine for the Magic-Sudoku app: board state, puzzle generation, hint solving, validation, and difficulty rating. It has no UI; presentation (including human-facing hint explanations via `HintExplainer`) and puzzle retrieval (`PuzzleDistribution`) live in the Magic-Sudoku repo.

## Package Map

Single library product `SudokuCore`, one test target, one benchmark executable.

| Target | Purpose |
|---|---|
| `SudokuCore` | The engine library (56 source files) |
| `SudokuCoreTests` | Swift Testing suites (26 files) with JSON fixtures |
| `SudokuCoreBenchmarks` | package-benchmark executable (7 files) |

Dependencies: `swift-collections` (1.1+), `swift-numerics` (1.0+), `swift-algorithms` (1.2+), `package-benchmark` (1.29+, benchmark target only).

### Source Layout (`Sources/SudokuCore/`)

- **CoreModels/** — `Puzzle`, `Puzzle.Index`, `PuzzleDifficulty`, `SudokuUnit`, `Board.UndoStep`, `Solution`/`PencilMarks` typealiases, precomputed lookup tables
- **Board/** — `Board` class plus extensions (`Board+Marking`, `Board+UndoRedo`, `Board+Validation`, `Board+Checking`, `Board+Helpers`, `Board+StateRestoration`), `Board.Cell`, `CellBackground`
- **Generation/** — `SolutionGenerator`, `SudokuGenerator`, `PuzzleCreator`, `SudokuSolver`, `SudokuValidator`, `SudokuDifficultyCalculator`, `PerformanceScoreCalculator`
- **Hints/** — `HintFinder` (+ helpers), `Hints.swift` (`HintTechnique`, `HintStep`, `HintAction`), `HintReasoning`, `BoardState`, `BoardStateParser`, `SolveUtilities`; technique implementations in `Hint Implementation/`
- **Rating/** — `HoDoKuCalculator`, `SECalculator`, `SolvePathEmitter`, `PersonalizedCalibrator`, `TimeEstimator`, `TechniqueMapping`, `RatingTables`
- **Documentation.docc/** — 8 DocC articles (QuickStart, CoreConcepts, HintSystem, WorkingWithBoards, GeneratingPuzzles, DifficultyRating, ValidationSystem)
- **Services/** — currently empty

## Domain Model

### Core value types (all `Sendable`, mostly `Codable`)

- **`Puzzle`** (struct) — immutable puzzle definition: `id`, `solution: [[Int]]`, `startingState: [[Int]]`, `difficulty: PuzzleDifficulty`
- **`Puzzle.Index`** (struct) — row/column position; `allIndices`, `houseNumber`, `houseIndices`; extensions for orientation and neighbours
- **`PuzzleDifficulty`** (struct) — `level: Level` (easy/medium/hard/expert/professional/custom) plus quantitative fields: `hardestTechnique`, `score`, `seRating`, `hodokuRating`, `estimatedTimeSeconds`
- **`SudokuUnit`** (enum) — `.row(Int)` / `.column(Int)` / `.house(Int)` with unit-position helpers
- **`Board.UndoStep`** (struct) — snapshot of cells, changed indices, validity flags, timestamp

### Board (the only class)

`Board` is `@Observable @MainActor` — the mutable gameplay state for SwiftUI. Holds 81 `Board.Cell` structs in a flat row-major array, plus derived state: `completedRows/Columns/Houses/Numbers`, `isSolved`, `isSolvable`, statistics (`incorrectMoves`, `hintsUsed`, `noteUpdates`), `undoStack`, and `autoPencilMode`.

`Board.Cell` (struct) carries `position`, `isGiven`, `value`, `simplePencilMarks`, `advancedPencilMarks`, `ruledOutCandidates`, `validOptions`, `correctAnswer`, and `background` (`CellBackground`: clear/candidate/highlight/conflict/selected). `allowedValues` = `validOptions − ruledOutCandidates`.

### Hints

- **`HintTechnique`** (enum, 22 cases) — from `validation` and `nakedSingle` up to `finnedJellyfish` and `wWing`; each case knows its `difficulty`, SE id/step value, and HoDoKu id/points; `orderedCases` defines solve-path ordering
- **`HintStep`** — `actions: [HintAction]` + `technique` + `reasoning`
- **`HintAction`** — `position` + `ActionType` (`.solveAs`, `.ruleOut`, `.pencilIn`, `.clear`)
- **`HintReasoning`** — machine-readable record of the deduction: `focusDigits`, `units`, `components` (roles: subject/constraint/subset/pivot/wing/base/cover/fin/eliminated, each with `CellFact` snapshots), `placements`/`eliminations` (`CandidateRef`). `inconsistencies(in:)` validates the recorded premises against a live board to detect stale hints
- **`BoardState`** (struct, Sendable) — immutable snapshot (`grid`, `pencilMarks`, `validOptions`, `solution`) used by hints and rating; produced via `Board.state`

## Data Flow

### Generation pipeline

1. `SolutionGenerator.generateRandomSolution()` — backtracking with arc-consistency variant available
2. `SudokuGenerator.createPuzzle(from:targetEmpty:...)` (async) — removes cells in shuffled order, validating uniqueness in batches of 5
3. `SudokuDifficultyCalculator` — analyzes the resulting puzzle
4. `PuzzleCreator` orchestrates the above into a `Puzzle`

`SudokuSolver.solve(grid:)` (arc consistency + domain splitting) and `SudokuValidator` (`isValid`, `isCompleteAndValidSolution`, `hasUniqueSolution`) support the pipeline.

### Gameplay loop

```
Puzzle → Board(puzzle:) → 81 Cells
player action (mark/pencil/clear)
  → saveState() pushes UndoStep
  → mutate cells
  → refreshDerivedState(): validOptions, completed units, isSolved, isSolvable
undo() → pop stack, restore cells, refresh
```

Compound operations (applying a hint, loading state) set `isPerformingAtomicChange` so multi-cell mutations record a single undo entry. `recoverToLastCorrectState()` rewinds to the last valid snapshot.

### Hint flow

`Board.state` → `BoardState` snapshot → `HintFinder.findHint(for:in:)` dispatches to the technique finder → `HintStep` with actions + `HintReasoning`. The app renders reasoning itself (no explanation text in core).

### Rating flow

`SolvePathEmitter.emit(from:)` repeatedly applies the cheapest available hint (per `HintTechnique.orderedCases`) producing a `SolvePath` of technique-annotated steps → `HoDoKuCalculator` (cumulative effort, with per-technique breakdown) and `SECalculator` (peak step difficulty). `TimeEstimator` produces baseline solve-time estimates; `PersonalizedCalibrator` (struct with `Anchor`/`Sample`/`Estimate`) adjusts them per player from observed samples. `RatingTables` holds precomputed thresholds; `TechniqueMapping` maps techniques to SE/HoDoKu ids.

## Current Capabilities

### Solving techniques (13 implementation files in `Hints/Hint Implementation/`)

- **Singles:** naked single, hidden single
- **Subsets:** naked/hidden pairs, triples, quads
- **Locked candidates:** pointing, claiming
- **Fish:** X-Wing, Swordfish, Jellyfish + finned variants of each (`FishPatterns.swift`, parameterized by size and fin requirement)
- **Single-digit patterns:** Skyscraper, Two-String Kite, Empty Rectangle
- **Wings:** XY-Wing, XYZ-Wing, Y-Wing, W-Wing
- **Validation:** conflict detection as a hint technique (points out player errors)

### Board features

Value placement, simple + advanced pencil marks, ruled-out candidates, auto-pencil mode, full undo with checkpoints and recover-to-last-correct, completion tracking per row/column/house/number, conflict checking, state restoration (Codable persistence), gameplay statistics.

### Generation features

Target empty-cell count (difficulty proxy), guaranteed-unique solutions, async generation. No symmetry constraints — removal order is shuffled.

## Technical Notes

- **Extension-based organization** — `Board` split across focused `Board+*.swift` files; same pattern for `Index+Orientation`, `Index+Neighbours`, `Solution+String`, `Difficulty+Helpers`
- **Enum static-method APIs** — `HintFinder`, `SudokuGenerator`, `SudokuSolver`, `SudokuValidator`, calculators, and emitters are caseless enums with static methods; `Board` is the only class
- **Concurrency** — value types are `Sendable` throughout; `Board` is `@MainActor`-isolated and `@Observable`; generation APIs are `async`
- **Precomputed lookup tables** (`LookupTables.swift`) — `cellNeighbours` (20 peers per cell), `cellToBoxIndex`, `rowCells`/`columnCells`/`boxCells`, `allCells`; computed once at load
- **Logic/presentation split** — `HintReasoning` records *why* a hint holds as data; explanation text generation belongs to the app (`HintExplainer` in Magic-Sudoku). Explanation strings and localization were removed from core (commits 9a77e62, 7c79864)
- **Testing** — Swift Testing (`@Test`, `#expect`); grids as string constants; `BoardStateParser` parses the sudoku.coach format; fixtures in `Tests/SudokuCoreTests/Fixtures/` (e.g. `standard-hard.json`); coverage spans board ops (8 files), hints (5), rating (5), generation (2), plus validators/solvers/utilities
- **Benchmarks** — package-benchmark suites for generation, hint finding, difficulty calculation, validation, and calibration; `./benchmark_compare.sh` compares against a stored baseline
