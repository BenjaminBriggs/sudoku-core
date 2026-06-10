# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
swift build                  # Debug build
swift build -c release       # Release build
swift test                   # Run all tests
swift test --filter SudokuCoreTests.BoardTests  # Run a single test suite
```

Documentation builds via Xcode (Product > Build Documentation); the swift-docc-plugin is not a package dependency.

### Benchmarks

```bash
swift build --product SudokuCoreBenchmarks
./benchmark_compare.sh       # Compare against baseline
```

## Architecture

SudokuCore is a Swift 6 package (iOS 18+/macOS 15+) providing Sudoku game mechanics, puzzle generation, hint solving, and difficulty rating.

### Module Layout (Sources/SudokuCore/)

- **CoreModels/** — Foundation types: `Puzzle` (immutable definition with solution, startingState, difficulty, optional constraints + presentation payload), `Puzzle.Index` (row/col position), `PuzzleDifficulty`, `SudokuUnit` (row/column/house), `UndoStep`, `Solution` (typealias for `[[Int]]`)
- **Board/** — `Board` is the main `@Observable @MainActor` class managing gameplay state. Contains 81 `Board.Cell` objects in a flat row-major array. Applies constraint pruning to candidates and surfaces `constraintViolations`. Functionality split across extensions: `Board+Marking`, `Board+UndoRedo`, `Board+Validation`, `Board+Checking`, `Board+Helpers`, `Board+StateRestoration`
- **Constraints/** — Variant extension point: `Constraint` protocol (violations + candidate pruning), `AnyConstraint` (type-erased Codable wrapper, `{"type":…,"payload":…}`), `ConstraintRegistry` (typeID → type, register at startup). Variants are additive rules on the classic 9×9
- **Generation/** — Puzzle creation pipeline: `SolutionGenerator` (backtracking with bitset optimization) → `SudokuGenerator` (cell removal with uniqueness validation) → `SudokuDifficultyCalculator` → `PuzzleCreator` (orchestrator). Also includes `SudokuValidator` and `SudokuSolver`. Classic-only; the package does not generate variant puzzles
- **Hints/** — 23 classic solving techniques from naked singles to finned fish and wing patterns, as structs conforming to the `HintTechnique` protocol (identity via `TechniqueID`/`TechniqueInfo`). `ClassicTechniques.all` is the built-in set; `HintFinder.firstHint(in:using:)` takes any technique array, so apps and variant modules add their own. Uses `BoardState` (immutable snapshot, carries constraints) and returns `HintStep` with `HintAction` items and a machine-readable `HintReasoning` record of the deduction
- **Rating/** — Dual rating system: `HoDoKuCalculator` (cumulative effort) and `SECalculator` (peak difficulty). `SolvePathEmitter` generates technique-annotated solve paths. `PersonalizedCalibrator` adjusts for player skill. Classic-only; variant techniques carry no rating metadata

### SudokuKiller target (Sources/SudokuKiller/)

Killer sudoku variant module proving the extension points: `KillerCage` (`Constraint` with sum/no-repeat violations and combination-based pruning) plus `CageLastCell` and `CageCombinations` techniques. `KillerSudoku.register()` registers the cage type for decoding; combine `ClassicTechniques.all + KillerSudoku.techniques` for hint finding.

### Scope

The logic to play Sudoku — board state, generation, rating, validation — the hints, and utilities that make those easier. Human-facing explanation text lives in the Magic-Sudoku repo's `HintExplainer` package (built from `HintReasoning`); puzzle retrieval lives in its `PuzzleDistribution` package.

### Key Patterns

- **Extension-based organization** — Board functionality split into focused extensions rather than one large class
- **Enum-based APIs** — HintFinder, SudokuGenerator, Validator expose static methods on enums (no instances)
- **State snapshots** — `BoardState` and `UndoStep` provide immutable state for passing between components
- **Precomputed lookup tables** — Index neighbors, house mappings computed once for performance
- **Swift Concurrency** — `@Observable` for SwiftUI, `@MainActor` for thread safety, `Sendable` types throughout

### Testing

Tests use Swift Testing framework (`@Test` macro, `#expect` assertions). Test grids are stored as string constants. JSON fixtures live in `Tests/SudokuCoreTests/Fixtures/`.

### Dependencies

- `swift-collections` — Extended collection types
- `swift-numerics` — Numeric operations
- `swift-algorithms` — Algorithm utilities
- `package-benchmark` — Benchmarking (benchmark target only)
