# Repository Guidelines

## Project Structure & Module Organization
- Source: `Sources/SudokuCore/` — modules: `Board/`, `CoreModels/`, `Generation/`, `Hints/`, `Rating/`, `Models/`, `Documentation.docc/`, plus `Localizable.xcstrings`.
- Tests: `Tests/SudokuCoreTests/` — `*Tests.swift` files and `Fixtures/` for JSON and other assets.
- Benchmarks: `Benchmarks/SudokuCoreBenchmarks/` (executable target).
- Package manifest: `Package.swift` (Swift 6, iOS 18+/macOS 15+).

## Build, Test, and Development Commands
- `swift build` — Debug build. `swift build -c release` — Release build.
- `swift test` — Run all tests. Example: `swift test --filter Board` to run Board-related tests.
- Docs: `swift package --disable-sandbox preview-documentation --target SudokuCore` to preview DocC.
- Benchmarks: `swift build --product SudokuCoreBenchmarks`; compare vs baseline with `./benchmark_compare.sh`.

## Coding Style & Naming Conventions
- Swift 6; follow Swift API Design Guidelines. Indent 4 spaces, no tabs; keep lines ~120 chars.
- Types `PascalCase`; methods/properties `camelCase`; files match primary type (e.g., `Puzzle.swift`).
- Prefer focused extensions (e.g., `Board+Validation.swift`, `Board+Marking.swift`).
- Use `@Observable` and `@MainActor` where appropriate; favour immutability in models.
- Format with Xcode’s default formatter; keep diffs minimal (no drive‑by reformatting).

## Testing Guidelines
- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`).
- Location: `Tests/SudokuCoreTests/…`; name files `FeatureNameTests.swift` (e.g., `BoardValidationTests.swift`).
- Add tests for all new behavior and bug fixes; keep fixtures under `Tests/SudokuCoreTests/Fixtures/`.
- Run: `swift test` (use `--filter` to narrow scope).

## Commit & Pull Request Guidelines
- Commits: imperative mood, concise subject, optional scope (e.g., `Board: fix house validation`).
- PRs: clear description, linked issues, rationale, and test evidence. Include benchmark output when performance changes (`./benchmark_compare.sh`).
- Required before merge: all tests pass; docs updated in `Sources/SudokuCore/Documentation.docc` when APIs change.

## Security & Configuration Tips
- Library performs no network I/O; avoid secrets. Keep generators/solvers deterministic and thread‑safe.
- Supported toolchain: Swift 6, Xcode 16, iOS 18+/macOS 15+.

## Agent-Specific Notes
- Preserve module layout and filenames to keep DocC links stable.
- Avoid broad renames or reformat‑only PRs; keep changes surgical and focused.

