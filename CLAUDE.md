# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
swift build                  # Debug build
swift build -c release       # Release build
swift test                   # Run all tests
swift test --filter SudokuCoreTests.BoardTests  # Run a single test suite
swift package --disable-sandbox preview-documentation --target SudokuCore  # Preview docs
```

### Benchmarks

```bash
swift build --product SudokuCoreBenchmarks
./benchmark_compare.sh       # Compare against baseline
```

## Architecture

SudokuCore is a Swift 6 package (iOS 18+/macOS 15+) providing Sudoku game mechanics, puzzle generation, hint solving, and difficulty rating. Localization is en-GB.

### Module Layout (Sources/SudokuCore/)

- **CoreModels/** — Foundation types: `Puzzle` (immutable definition with solution, startingState, difficulty), `Puzzle.Index` (row/col position), `PuzzleDifficulty`, `UndoStep`, `Solution` (typealias for `[[Int]]`)
- **Board/** — `Board` is the main `@Observable @MainActor` class managing gameplay state. Contains 81 `Board.Cell` objects in a flat row-major array. Functionality split across extensions: `Board+Marking`, `Board+UndoRedo`, `Board+Validation`, `Board+Checking`, `Board+Helpers`
- **Generation/** — Puzzle creation pipeline: `SolutionGenerator` (backtracking with bitset optimization) → `SudokuGenerator` (cell removal with uniqueness validation) → `SudokuDifficultyCalculator` → `PuzzleCreator` (orchestrator). Also includes `SudokuValidator` and `SudokuSolver`
- **Hints/** — 18+ solving techniques from naked singles to finned fish patterns. `HintFinder` dispatches to technique implementations in `Hint Implementation/`. Uses `BoardState` (immutable snapshot) and returns `HintStep` with `HintAction` items and localized `HintExplanationStep` explanations
- **Rating/** — Dual rating system: `HoDoKuCalculator` (cumulative effort) and `SECalculator` (peak difficulty). `SolvePathEmitter` generates technique-annotated solve paths. `PersonalizedCalibrator` adjusts for player skill
- **Models/** — `PuzzleManifest`, `MonthlyPuzzleManifest`, `PuzzleServerConfig`

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
