# SudokuCore Audit Findings

> Generated: 2026-05-07 (Round 1, 135 findings)
> Re-audit: 2026-06-02 (Round 2 — see "Round 2: Verification + Additional Findings" section near end)
> Scope: every file in `Sources/SudokuCore/` and `Tests/SudokuCoreTests/`.
> Status: complete (149 total findings — 135 Round 1 + 14 Round 2; 1 Round 1 finding Disputed, 7 severity disagreements documented).

## How to use this document

Each finding has a verified line-level reference. Before fixing, re-read the cited code — the line numbers are accurate as of audit time but may have drifted if other changes have shipped.

**Severity levels**:
- **Critical** — observable wrong behavior (returns wrong answer, corrupts state, crashes on plausible input).
- **High** — incorrect under specific conditions, or significant performance regression on hot paths.
- **Medium** — minor incorrect behavior, suboptimal algorithms, fragile invariants.
- **Low** — code quality, dead code, doc/comment drift, micro-optimizations.

**Categories**: correctness, performance, concurrency, API, data integrity, localization, robustness, dead code, documentation.

**For the fixer agent**:
1. Fix Critical first, then High, etc. (Start with **[R2-001]** which is the only new High.)
2. For each fix, run `swift test` and confirm no regressions.
3. If a finding has a "Verification after fix" entry, add the test it describes.
4. If you disagree with a finding (false positive, intended behavior), leave it in the doc and add a `**Resolution: not a bug**` line with reasoning rather than deleting it.
5. Several findings include design questions (e.g. should HoDoKu rating include a per-elimination modifier?). For those, ask the user before changing semantics.
6. **Round 2 rules**: All Round 1 findings default to **Verified** unless listed in "Disputed" or "Severity Disagreements" in the Round 2 section. Read that section before starting any fix to confirm status.

---

## Sources/SudokuCore findings

### CoreModels/Solution.swift

#### [Low] `Solution = [[Int]]` is a nested array — cache-hostile
- **Category**: performance
- **File**: `Sources/SudokuCore/CoreModels/Solution.swift:9`
- **Code**:
  ```swift
  public typealias Solution = [[Int]]
  ```
- **Failure mode**: every `solution[row][col]` access dereferences two pointers and pulls in a separate inner-array allocation. For an 81-int grid, a flat `[Int]` (or fixed-size 81-tuple) would fit in two cache lines and iterate as straight-line memory. With nested arrays, each inner row is a distinct heap allocation (or COW-shared row); iterating row-by-row is fine but column iteration thrashes cache. Solver and validator hot paths spend significant time on this access pattern.
- **Test coverage**: none of the existing tests measure this; benchmarks would show the win.
- **Suggested fix**: large refactor — change `Solution` to a struct wrapping a `[Int]` of 81 elements with `subscript(row:col:)`. Migrate call sites incrementally. If this is too disruptive, leave as-is and document the perf cost.
- **Verification after fix**: benchmarks should show 1.5-3× speed-up in solver/validator throughput. Existing tests should still pass.

#### [Medium] `Solution.cells(from:)` silently returns empty grid on length mismatch
- **Category**: robustness / API
- **File**: `Sources/SudokuCore/CoreModels/Solution+String.swift:13-15`
- **Code**:
  ```swift
  guard startingPositions.count == 81 else {
      return givenCells
  }
  ```
- **Failure mode**: a caller passing an 80-character or 82-character string gets back a fully-empty 9×9 grid with no error. `Board(string:)` and other callers can't distinguish between "valid empty grid" and "parser rejected your input." A typo in a saved-state string disappears silently.
- **Test coverage**: not directly tested for length mismatch.
- **Suggested fix**: change return type to `[[Int]]?` returning nil on invalid length, or throw a `BoardStateParseError`. Update `Board(string:)` to handle the failure case (likely fall back to empty board with logging).
- **Verification after fix**: add a test asserting that an 80-char string produces nil/throws and that the grid round-trips for 81-char inputs.

#### [Low] `Solution.cells(from:)` does a gratuitous "0" → "#" replacement
- **Category**: code quality
- **File**: `Sources/SudokuCore/CoreModels/Solution+String.swift:17`
- **Code**:
  ```swift
  let startingPositions = startingPositions.replacingOccurrences(of: "0", with: "#")
  ```
- **Failure mode**: `Int(String("0"))` is `0`, and the grid initialises empty cells to `0` already, so writing `0` to an already-zero cell is a no-op. The `#` substitution avoids that no-op write at the cost of one full-string allocation per call.
- **Test coverage**: behavior is correct, just wasteful.
- **Suggested fix**: delete line 17 and the `replacingOccurrences` call; the loop already handles `"0"` correctly.

#### [Low] `Solution.randomNotValid()` advertised as "not valid" but doesn't enforce that
- **Category**: API / documentation
- **File**: `Sources/SudokuCore/CoreModels/Solution.swift:13-21`
- **Code**:
  ```swift
  public static func randomNotValid() -> Solution {
      var solution = Solution.empty()
      for row in 0..<9 {
          for col in 0..<9 {
              solution[row][col] = Int.random(in: 1...9)
          }
      }
      return solution
  }
  ```
- **Failure mode**: the name promises an invalid grid, but with vanishingly small probability the generator could (in theory) emit a valid-looking grid. More importantly: tests using this helper to create "an invalid grid" rely on probabilistic invalidity. If any test assumes `Validator.isComplete(...)` returns false on the result, it could flake.
- **Test coverage**: depends on caller; usually tests treat the output as "definitely invalid" without re-checking.
- **Suggested fix**: rename to `randomGrid()` (truthful) or actually force invalidity (e.g. set `[0][0] = [0][1] = 1`). The rename is safer since other code might depend on the helper.

### CoreModels/Index.swift

#### [Medium] `Puzzle.Index.allIndices` is a computed property recomputed on every call
- **Category**: performance
- **File**: `Sources/SudokuCore/CoreModels/Index.swift:69-75`
- **Code**:
  ```swift
  public static var allIndices: [Puzzle.Index] {
      (0..<9).flatMap { r in
          (0..<9).map { c in
              Puzzle.Index(row: r, column: c)
          }
      }
  }
  ```
- **Failure mode**: every access allocates a new 81-element array and 81 `Puzzle.Index` structs. Called from `SudokuGenerator.createPuzzle` (line 40) every generation attempt, and `Board.allHouses` (line 19). In a 20-attempt difficulty-targeted generation loop that's 20+ unnecessary allocations.
- **Test coverage**: not measured.
- **Suggested fix**: change to `static let`. Already done correctly for `LookupTables.allCells` — `allIndices` should just delegate (`return LookupTables.allCells`) or both should be unified.
- **Verification after fix**: existing tests pass; benchmark generation throughput shows reduced allocation count.

#### [Low] `Puzzle.Index.init` accepts out-of-range row/column without validation
- **Category**: API / robustness
- **File**: `Sources/SudokuCore/CoreModels/Index.swift:52-55`
- **Code**:
  ```swift
  public init(row: Int, column: Int) {
      self.row = row
      self.column = column
  }
  ```
- **Failure mode**: `Puzzle.Index(row: 9, column: 0)` constructs successfully and crashes later when used as an array index, with a stack trace far from the bad input. Same for negative values.
- **Test coverage**: no tests exercise invalid inputs.
- **Suggested fix**: add `precondition((0..<9).contains(row), "row out of range")` and same for column. Cheap in release builds, catches bugs in development.

#### [Low] `Puzzle.Index.hash(into:)` is hand-written but identical to synthesised version
- **Category**: code quality
- **File**: `Sources/SudokuCore/CoreModels/Index.swift:57-60`
- **Code**:
  ```swift
  public func hash(into hasher: inout Hasher) {
      hasher.combine(row)
      hasher.combine(column)
  }
  ```
- **Failure mode**: the struct already conforms to `Hashable` and Swift would synthesise an identical implementation. Hand-writing the hash function is dead code that has to be maintained.
- **Suggested fix**: delete `hash(into:)`; let the compiler synthesise.

### CoreModels/Index+Orientation.swift

#### [Medium] `houseIndices` rebuilds 9-element array on every access; should use `LookupTables.boxCells`
- **Category**: performance
- **File**: `Sources/SudokuCore/CoreModels/Index+Orientation.swift:71-83`
- **Code**:
  ```swift
  public var houseIndices: [Puzzle.Index] {
      var indices: [Puzzle.Index] = []
      let houseRowStart = (row / 3) * 3
      let houseColStart = (column / 3) * 3
      for r in houseRowStart..<(houseRowStart + 3) {
          for c in houseColStart..<(houseColStart + 3) {
              indices.append(Puzzle.Index(row: r, column: c))
          }
      }
      return indices
  }
  ```
- **Failure mode**: `LookupTables.boxCells[houseNumber]` already gives the same array, precomputed once. Hint techniques call `houseIndices` in inner loops; each call allocates a new 9-element array.
- **Test coverage**: behavior is correct, perf is not measured.
- **Suggested fix**: replace body with `LookupTables.boxCells[houseNumber]`.

#### [Low] `cells(in:)` for row/column uses `Set(0..<9).map(...).reduce(into: Set)` — pointless reduction
- **Category**: code quality / performance
- **File**: `Sources/SudokuCore/CoreModels/Index+Orientation.swift:36-63`
- **Code**: see file
- **Failure mode**: `Set(0..<9).map { ... }` produces an array (`map` on a Set returns an array), then `reduce(into: Set)` rebuilds a Set. Could be `Set((0..<9).map { Puzzle.Index(row: $0, column: self.column) })` — one less collection materialisation. The starting `Set(0..<9)` is also unnecessary; `(0..<9)` is a Range and iterates fine. Hint techniques call this in loops.
- **Suggested fix**:
  ```swift
  public func cells(in orientation: Puzzle.Index.Orientation) -> Set<Puzzle.Index> {
      switch orientation {
      case .column: return Set(LookupTables.columnCells[column])
      case .row: return Set(LookupTables.rowCells[row])
      case .house: return Set(houseIndices)
      }
  }
  ```

#### [Low] `Puzzle.Index.cellsInHouse` duplicates `LookupTables.boxCells` and `houseIndices` logic
- **Category**: code quality
- **File**: `Sources/SudokuCore/CoreModels/Index+Orientation.swift:85-93`
- **Suggested fix**: delegate to `LookupTables.boxCells[house]`.

### CoreModels/Index+Neighbours.swift

#### [Low] `allNeighbours` returns only 4 cardinal neighbours despite enum supporting 8
- **Category**: API / naming
- **File**: `Sources/SudokuCore/CoreModels/Index+Neighbours.swift:17-24`
- **Code**:
  ```swift
  public var allNeighbours: [Puzzle.Index] {
      [neighbour(in: .right), neighbour(in: .left),
       neighbour(in: .top),   neighbour(in: .bottom)].compactMap { $0 }
  }
  ```
- **Failure mode**: the name suggests "all" but only includes 4 of the 8 directions defined on `Puzzle.Direction`. Tests document this ("returns only cardinal neighbours") so it's intentional, but the name is misleading. A new contributor could write code expecting diagonals.
- **Suggested fix**: rename to `cardinalNeighbours`. If `allNeighbours` is needed for backward compat, add a deprecated alias. Alternatively, add a separate `eightWayNeighbours` for the diagonal-inclusive case.

### CoreModels/LookupTables.swift

#### [Low] `cellNeighbours` uses `Set<Puzzle.Index>` where an `[Puzzle.Index]` would be smaller and faster
- **Category**: performance / data structure
- **File**: `Sources/SudokuCore/CoreModels/LookupTables.swift:14-47`
- **Code**: see file
- **Failure mode**: each cell's 20 peers are stored in a Set, which on Apple platforms means a Bridge-able NSSet-style hash table for 20 ints — about 240+ bytes each, vs ~160 bytes for a flat `[Puzzle.Index]`. Iteration order is unspecified (so iterating peers can produce different traversal each run, which subtly affects test determinism). Lookup is O(1) for `contains` but iteration is the only operation actually used in solver/hint hot paths — and array iteration is faster than Set iteration. The Set form is only useful if `contains` is on the hot path; check call sites confirm only iteration and `contains` (rare) are used.
- **Test coverage**: peer-iteration ordering isn't asserted, but if any technique's tests are sensitive to traversal order, results may flake on Set rehash.
- **Suggested fix**: change to `[[Puzzle.Index]]` (lookup index → array of 20 peers, same shape). Where `contains` is needed, compute a separate `[[Bool]]` table or convert at call site.

### Generation/SolutionGenerator.swift

#### [Medium] `(1...9).shuffled()` allocated per cell during backtracking
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SolutionGenerator.swift:91`
- **Code**:
  ```swift
  for num in (1...9).shuffled() {
  ```
- **Failure mode**: every recursive call (up to 81 + backtrack-retries) allocates a new 9-element array via `Range.shuffled()`. The shuffle itself is cheap, but the allocations add up across thousands of generation calls (especially in `PuzzleCreator` with `maxAttempts: 20`). More importantly, this is the only randomness in the generator — calling it once per cell is fine; the cost is allocation, not entropy.
- **Test coverage**: not measured.
- **Suggested fix**: pre-allocate one `var digits = Array(1...9)` outside the recursion and call `digits.shuffle()` per cell. Even better: use a single shuffled array per call to `fillWithBacktracking` and reshuffle only on backtrack.
- **Verification after fix**: profile generation throughput; expect modest improvement.

#### [Low] `generateRandomSolution` retry loop is dead — `fillWithBacktracking` from empty grid always succeeds
- **Category**: dead code
- **File**: `Sources/SudokuCore/Generation/SolutionGenerator.swift:21-23`
- **Code**:
  ```swift
  while !fillWithBacktracking(&grid) {
      grid = Solution.empty()
  }
  ```
- **Failure mode**: the backtracker is exhaustive over a fully empty grid — there's always a solution and it always finds one, so the `false` branch is never taken. The retry exists as a defensive guard but adds cognitive overhead. If the function ever changes to take a partial grid, the retry could enter an infinite loop on unsolvable inputs without warning.
- **Suggested fix**: replace with a single call and `precondition` or `assert` that it returned true:
  ```swift
  let ok = fillWithBacktracking(&grid)
  assert(ok, "fillWithBacktracking failed on empty grid")
  return grid
  ```

#### [Low] `fillWithBacktracking` precomputes used-bit sets even though the public API only ever passes empty grids
- **Category**: dead code / performance
- **File**: `Sources/SudokuCore/Generation/SolutionGenerator.swift:38-49`
- **Failure mode**: the `for row, col in grid` precompute (39-48) only fires for non-zero cells. From `generateRandomSolution`'s entry point, the grid is empty so this loop does nothing. The function is private with no other call sites. Wasted work.
- **Suggested fix**: either (a) skip the precompute since callers always pass empty grids, or (b) keep the precompute and expose `fillWithBacktracking` so external callers can pre-fill the grid (useful for puzzle-from-template generation). Pick one and document.

### Generation/SudokuValidator.swift

#### [Low] `Validator.isValid` makes a full grid copy to zero one cell
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SudokuValidator.swift:18-19`
- **Code**:
  ```swift
  var grid = grid
  grid[row][column] = 0
  ```
- **Failure mode**: COW means the actual deep copy only happens if the inner row is mutated, but `grid[row][column] = 0` does mutate, triggering the copy. For a hot validator path called during hint search, this is one allocation per call.
- **Suggested fix**: rewrite to skip the cell explicitly without mutating:
  ```swift
  // existing isInRow excluded position
  for c in 0..<9 where c != column && grid[row][c] == num { return false }
  ```
  Add `(row != self.row, col != self.col)` exclusions to `isInRow/Column/House` overloads.

#### [Low] Three private dead helpers (`hasDuplicateInRow/Column/House`) duplicate `hasNoConflicts` logic
- **Category**: dead code
- **File**: `Sources/SudokuCore/Generation/SudokuValidator.swift:140-185`
- **Failure mode**: not called anywhere (`grep` confirms no internal or test uses). They're 45 lines of unreachable code that drift out of sync with `hasNoConflicts` if either is updated.
- **Suggested fix**: delete them.

#### [Low] `countBits` private helper is a one-liner wrapping `Int.nonzeroBitCount`
- **Category**: dead code / code quality
- **File**: `Sources/SudokuCore/Generation/SudokuValidator.swift:364-367`
- **Code**:
  ```swift
  private static func countBits(_ n: Int) -> Int {
      n.nonzeroBitCount
  }
  ```
- **Failure mode**: only one call site (line 372), and the function does nothing the call site can't do directly.
- **Suggested fix**: inline `n.nonzeroBitCount` at the call site and delete the helper.

#### [Low] `validOptions` writes empty Set for already-filled cells when the array default is already empty
- **Category**: code quality / micro-perf
- **File**: `Sources/SudokuCore/Generation/SudokuValidator.swift:411-412`
- **Code**:
  ```swift
  if grid[row][col] != 0 {
      validOptions[row][col] = []
  } else { ... }
  ```
- **Failure mode**: `validOptions` is initialized with `[]` already (line 387). Reassigning `[]` is a no-op write that may break Swift's COW shared-init optimization.
- **Suggested fix**:
  ```swift
  guard grid[row][col] == 0 else { continue }
  // ... compute available, write
  ```

### Generation/SudokuSolver.swift

#### [Medium] `applyArcConsistency` queue cleanup uses O(n) `removeFirst(n)` to trim processed entries
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SudokuSolver.swift:97-101`
- **Code**:
  ```swift
  if queueIndex > 100 && queueIndex > queue.count / 2 {
      queue.removeFirst(queueIndex)
      queueIndex = 0
  }
  ```
- **Failure mode**: this is correct behaviour (it does keep the unprocessed tail), but `Array.removeFirst(n)` is O(remaining) — copies all remaining elements down. On a dense puzzle the queue can grow into the hundreds; trimming is amortised O(n²) across the lifetime of a `solve()` call. A real deque (`Deque` from `swift-collections`, already a package dependency) gives O(1) pop-front and avoids the trimming dance entirely.
- **Test coverage**: solver correctness is tested; throughput isn't.
- **Suggested fix**: replace the `[(row, col)]` queue + index pair with `Deque<(Int, Int)>` from swift-collections, using `popFirst()` for consumption.

#### [Medium] Solver domains use `Set<Int>` instead of `Int` bitset (validator already uses bitset)
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SudokuSolver.swift:11-13`
- **Code**:
  ```swift
  private typealias Domain = Set<Int>
  private typealias DomainGrid = [[Domain]]
  ```
- **Failure mode**: `Set<Int>` for ≤9 elements is heavyweight. Each cell's domain holds a hash table of up to 9 ints, with Set operations (insert, remove, contains, count) being O(1) but with significantly higher constant factors than bitset ops. AC3 propagation copies, modifies, and writes back domains — every operation pays the Set cost. The `SudokuValidator` already moved to bitsets (line 191 uses `typealias Domain = Int`); the solver hasn't been migrated.
- **Test coverage**: solver tests exercise correctness; benchmarks would show the perf delta.
- **Suggested fix**: change `Domain = Int` (bitset over digits 1-9 in bits 0-8). Adjust `processConstraints` to use bitwise AND-NOT for "remove value", `nonzeroBitCount` for size, etc. Use `LookupTables.bitsetToSet` only at the boundary where `Set<Int>` is needed externally.
- **Verification after fix**: existing solver tests pass; benchmark shows improvement.

#### [Medium] `findMRVCell` doesn't early-exit when a singleton-domain cell is found
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SudokuSolver.swift:221-242`
- **Code**: linear scan that always visits all 81 cells.
- **Failure mode**: if a cell with `count == 1` is encountered (unsolvable detected via `domain.isEmpty` would be a separate concern; here we're talking about cells that are essentially decided but not yet propagated), the function still scans the full grid before returning. By contrast, `Validator.findMRVCell` (in `SudokuValidator.swift:347-350`) does early-exit on `count == 1`. Inconsistency between the two solvers, and a missed optimisation in the slower one.
- **Suggested fix**: mirror the validator: return immediately on `count == 1`. Doesn't change correctness; just pruning.

### Generation/SudokuGenerator.swift

#### [Low] `Puzzle.Index.allIndices` invocation re-allocates 81 indices each call
- **Category**: performance
- **File**: `Sources/SudokuCore/Generation/SudokuGenerator.swift:40-42`
- **Code**:
  ```swift
  var cells = cellsOrder ?? Puzzle.Index.allIndices
  if cellsOrder == nil {
      cells.shuffle()
  }
  ```
- **Failure mode**: see CoreModels finding above — `Puzzle.Index.allIndices` is a computed property that builds an array on each call. Fixing the upstream finding (make it a `static let`) addresses this automatically. Until then, callers in hot paths pay the allocation.
- **Suggested fix**: covered by the `Puzzle.Index.allIndices` fix.

#### [Low] Cell removal logic is a back-trim heuristic, not optimal
- **Category**: design / quality
- **File**: `Sources/SudokuCore/Generation/SudokuGenerator.swift:74-96`
- **Failure mode**: when a 5-cell batch breaks uniqueness, the algorithm restores cells from the END until uniqueness returns. This finds the largest *suffix-trimmed* prefix that maintains uniqueness, which is correct but not optimal — there may be a different subset (e.g. {a, c, e} but not {b, d}) that would remove more cells while preserving uniqueness. Going through other orderings would cost more uniqueness checks but might produce more empty cells (and thus higher difficulty). Deliberate trade-off; document if this is intentional.
- **Suggested fix**: document the heuristic in the doc comment so future maintainers don't think it's exhaustive. No code change needed unless quality is tested and found wanting.

### Generation/PuzzleCreator.swift

#### [High] `createPuzzleWithDifficulty` silently returns wrong-difficulty puzzle when no match found
- **Category**: API contract
- **File**: `Sources/SudokuCore/Generation/PuzzleCreator.swift:128-138`
- **Code**:
  ```swift
  if let (puzzle, solution, difficultyResult) = bestMatch {
      return Puzzle(...)
  }
  // If we couldn't find a suitable puzzle, generate a basic one
  let (solution, startingState) = await SudokuGenerator.generatePuzzle()
  return try await createPuzzle(solution: solution, startingState: startingState)
  ```
- **Failure mode**: a caller asks for `.professional` (target range 116-120). After 20 failed attempts the function falls through to `SudokuGenerator.generatePuzzle()` (default empty-cell range 45-55), runs `createPuzzle` (which calculates difficulty without checking the level), and returns whatever falls out — typically `.easy` or `.medium`. The caller has no way to know the contract was violated. UI shipping this could show a "Professional" badge on a Beginner puzzle.
- **Test coverage**: tests likely don't force the impossible-target path.
- **Suggested fix**: throw a typed error (e.g. `PuzzleGenerationError.targetDifficultyNotAchieved(requested: level, bestAttempt: result.level, attempts: maxAttempts)`) instead of falling through. Callers can decide whether to retry or surface the failure.
- **Verification after fix**: add a test that requests `.professional` with `maxAttempts: 1` and asserts the throw.

#### [Low] Difficulty target ranges overlap between expert/professional/custom
- **Category**: API consistency
- **File**: `Sources/SudokuCore/Generation/PuzzleCreator.swift:50-57`
- **Code**:
  ```swift
  .expert: 101...115,
  .professional: 116...120,
  .custom: 100...120,
  ```
- **Failure mode**: `.custom` overlaps with both `.expert` and `.professional`. If a fixed puzzle has hardestTechnique difficulty 110 (xyWing/yWing), it could legitimately be classified as `.expert` or `.custom` depending on caller intent. Not a bug per se, but the contract is fuzzy.
- **Suggested fix**: either narrow `.custom`'s range or document it as "any level — used for caller-provided puzzles."

### Generation/SudokuDifficultyCalculator.swift

#### [Medium] `DifficultyResult.score` documented as "normalised (0-1)" but actually holds raw HoDoKu rating
- **Category**: documentation / API
- **File**: `Sources/SudokuCore/Generation/SudokuDifficultyCalculator.swift:169-170`
- **Code**:
  ```swift
  /// A normalised difficulty score (0-1)
  public let score: Double
  ```
- **Failure mode**: the comment says 0-1, the value is `Double(hodokuRating ?? 1)` (line 134), which can be 1-2000+. Anyone reading the API to tune their UI will get the scale wrong. Also `puzzleDifficulty` (line 235) casts `Int(self.score)` and stores it — if `score` were ever a non-integer Double this would silently truncate.
- **Suggested fix**: fix the doc comment to "HoDoKu cumulative effort rating (1-2000+)" and consider changing the type to `Int` for consistency with `PuzzleDifficulty.score`. The type change is a breaking API change; do it deliberately.

#### [Medium] Empty-techniques shortcut returns `score: 1.0` and level `.easy` regardless of actual state
- **Category**: correctness / edge case
- **File**: `Sources/SudokuCore/Generation/SudokuDifficultyCalculator.swift:122-130`
- **Code**:
  ```swift
  if techniquesUsed.isEmpty {
      return DifficultyResult(level: .easy, score: 1.0, ...)
  }
  ```
- **Failure mode**: `techniquesUsed.isEmpty` happens when the input grid was already solved (no steps required). The function returns `level: .easy, score: 1.0`. This is misleading — a solved grid has no difficulty; it isn't `.easy`. Callers building puzzle pickers might count it as "an easy puzzle to add to the pool."
- **Suggested fix**: either throw a dedicated error (`DifficultyError.alreadySolved`) or introduce a sentinel level (`.completed`). The `.easy` fallback is a footgun.

#### [Medium] Fallback solver path under-rates puzzles requiring techniques beyond the hint system
- **Category**: correctness
- **File**: `Sources/SudokuCore/Generation/SudokuDifficultyCalculator.swift:66-83`
- **Code**: the fallback at lines 67-72 calls `SudokuSolver.solve` (Arc Consistency + domain splitting) when the hint-based path stalls.
- **Failure mode**: when the hint-finder can't fully solve a puzzle, the calculator falls back to the AC solver, marks the techniques as `[..., .unknown]`, and reports `wasSolved: true`. The `hardestTechnique` filter at line 188 *excludes* `.unknown`, so the rating is based on whatever easier techniques fired before the stall. A puzzle requiring chains beyond `xyzWing` (difficulty 120) gets reported with hardestTechnique = `.xyWing` (110) and a HoDoKu rating that doesn't reflect the actual difficulty. Such puzzles will leak into `.expert` / `.professional` slots when they should be even harder (or marked unsolvable for grading purposes).
- **Test coverage**: depends on whether any test feeds the calculator a chain-required puzzle.
- **Suggested fix**: when the fallback is needed, either (a) inflate the rating by a fixed delta to reflect "beyond known techniques," or (b) refuse to grade and throw `DifficultyError.beyondKnownTechniques`. Option (b) is cleaner; (a) is more permissive for production use. Document whichever you pick.

#### [Medium] `puzzleDifficulty` fallback `hardestTechnique` mappings don't match their declared ranges
- **Category**: correctness
- **File**: `Sources/SudokuCore/Generation/SudokuDifficultyCalculator.swift:222-231`
- **Code**:
  ```swift
  case .easy: return .hiddenSingle           // diff 20  ✓ in 0-40
  case .medium: return .lockedCandidatesPointing // diff 40 ✗ medium is 41-70
  case .hard: return .xWing                   // diff 80  ✓ in 71-100
  case .expert: return .swordfish             // diff 90  ✗ expert is 101-115
  case .professional: return .xyWing          // diff 110 ✗ professional is 116-120
  case .custom: return .hiddenSingle          // diff 20  ?
  ```
  (Difficulty values are from `HintTechnique.difficulty` — see `Hints.swift:45-86`.)
- **Failure mode**: if `hardestTechnique` is nil and the fallback fires, the resulting `PuzzleDifficulty` has a level that doesn't match its hardestTechnique's difficulty. Downstream code that derives anything from `hardestTechnique.difficulty` (e.g. UI badges, analytics) will see inconsistent data.
- **Test coverage**: unlikely to be tested.
- **Suggested fix**: pick fallbacks whose `difficulty` is inside the level's range. Suggested mappings:
  - `.easy: .hiddenSingle` (20)
  - `.medium: .nakedPair` (50)  — change from .lockedCandidatesPointing
  - `.hard: .xWing` (80)
  - `.expert: .xyWing` (110)  — change from .swordfish
  - `.professional: .xyzWing` (120)  — change from .xyWing
  - `.custom: .nakedSingle` (10) or some neutral default

### Generation/PerformanceScoreCalculator.swift

#### [Low] `scaleToRange` upper bound `15353.0` is an unexplained magic number
- **Category**: documentation / fragility
- **File**: `Sources/SudokuCore/Generation/PerformanceScoreCalculator.swift:341-349`
- **Code**:
  ```swift
  let logMax = Foundation.log10(15353.0)  // log10(15353) ≈ 4.186
  ```
- **Failure mode**: the comment explains that `15353` is "the score cap so that excellent performance achieves ~97,500" but doesn't show the derivation. If the formula upstream changes (different timeMultiplier curve, different penalty rates, different perfect bonus), this number becomes stale silently. Future maintainers will struggle to recalibrate.
- **Suggested fix**: derive `15353` from the actual maximum: `2000 (max difficulty) * 3.0 (max timeMultiplier) * 1.0 (no penalty) * 1.15 (no-assistance) * 2.5 (perfect) ≈ 17,250` — or whatever the real ceiling is. Encode it as a computed `static let maxRawScore` with the derivation in a comment.

#### [Low] Time-multiplier asymmetry between fast and slow paths is undocumented
- **Category**: documentation
- **File**: `Sources/SudokuCore/Generation/PerformanceScoreCalculator.swift:201-211`
- **Failure mode**: solving in 2× target gives multiplier `1/(1+1) = 0.5`, but solving in 0.5× target gives `1 + 2*(1-0.5) = 2.0`. The reward asymmetry is intentional (rewarding speed more than penalising slowness) but isn't documented in code or doc comments.
- **Suggested fix**: add a one-line comment above the conditional explaining the design choice.

### Hints/BoardState.swift

#### [Medium] `BoardState` initialiser allows ill-formed grids (empty arrays, mismatched dimensions) silently
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/BoardState.swift:16-26`
- **Failure mode**: the default init takes `grid: [[Int]] = []` and `pencilMarks: [[Set<Int>]] = []`. An accidental `BoardState()` produces a struct whose internal arrays have count 0, which then crashes any `grid[row][col]` access far from the bug. The struct should require a 9×9 grid by construction.
- **Test coverage**: `BoardStateParser` validates inputs, but direct callers of `BoardState.init` don't.
- **Suggested fix**: either (a) add `precondition(grid.count == 9 && grid.allSatisfy { $0.count == 9 })` in the init, or (b) make the public init require non-default args and provide a `BoardState.empty()` static for cases that need an empty placeholder.

### Hints/SolveUtilities.swift

#### [Medium] `BoardState.applying` ignores `.pencilIn` actions entirely
- **Category**: correctness
- **File**: `Sources/SudokuCore/Hints/SolveUtilities.swift:43-44`
- **Code**:
  ```swift
  case .pencilIn(_):
      break
  ```
- **Failure mode**: when a hint includes a `.pencilIn` action (used by techniques that suggest the player add a candidate to a cell), `applying` discards it. The recomputed `validOptions` from the validator restores it implicitly only if the candidate is a valid option — meaning user-entered pencil marks for ruled-out values would be lost. More importantly, in `SolvePathEmitter.emit`, the path is built by repeatedly calling `applying` — so any technique that *only* adds pencilIn actions (rather than solveAs/ruleOut) creates a step that doesn't change the state, and the emitter's loop will infinite-loop until the iteration cap (line 51 in SolvePathEmitter.swift: `if iterations > maxIterations { break }`). It bails out, but slowly.
- **Test coverage**: `SolvePathEmitterTests` likely doesn't exercise pure-pencilIn techniques.
- **Suggested fix**: handle `.pencilIn` by adding the value to `newPencilMarks`. Check that no existing technique emits `.pencilIn`-only steps that would loop; if any does, fix it.

#### [Medium] `BoardState.applying` recomputes `validOptions` for the entire grid on every step
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/SolveUtilities.swift:50-56`
- **Failure mode**: every step recomputes the full `validOptions` table (81 cells, three constraint sets each), then loops 81 cells doing set intersections. For a 50-step solve path this is 50 × 81 = 4050 set computations. Most steps only change 1-3 cells; an incremental update would be ~2 orders of magnitude faster.
- **Test coverage**: not measured.
- **Suggested fix**: compute affected cells (peers of every modified position) and only recompute `validOptions` for those. Or, cache a row/col/box used-bits trio and update them per change.

#### [Low] `isSolved` does a manual zero scan and then a second pass via `hasNoConflicts`
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/SolveUtilities.swift:22-29`
- **Failure mode**: two full passes over the grid. `hasNoConflicts` already detects "any zero cell" implicitly only because non-zero conflicts wouldn't be a problem; but the function actually returns true on a partial grid as long as the placed digits don't conflict. So the zero-scan is needed. Still, both can be merged into a single pass.
- **Suggested fix**: low priority; only matters in very tight loops.

### Hints/HintFinder+Helpers.swift

#### [Low] `cellsOfIntrest` is misspelled (should be `cellsOfInterest`)
- **Category**: code quality
- **File**: `Sources/SudokuCore/Hints/HintFinder+Helpers.swift:243` and `Hint Implementation/HiddenSingles.swift:111`
- **Failure mode**: a typo in a public-internal helper. Doesn't affect behaviour but bothers readers and breaks search for "interest." It's a tracked source of confusion.
- **Suggested fix**: rename to `cellsOfInterest`. Internal-only usage so safe to do without deprecation.

#### [Low] `checkNoConflicts` duplicates `Validator.hasNoConflicts` (which uses bitsets — faster)
- **Category**: code quality / performance
- **File**: `Sources/SudokuCore/Hints/HintFinder+Helpers.swift:93-141`
- **Failure mode**: this implementation uses `Set<Int>` per row/col/box; `Validator.hasNoConflicts` does the same with bitsets and is faster. The HintFinder copy is only used by `Validation.swift:23`. Two implementations of the same conflict-detection logic that can drift.
- **Suggested fix**: replace `checkNoConflicts(in: state.grid)` call site with `Validator.hasNoConflicts(in: state.grid)` and delete the duplicate.

#### [Low] `getConstrainingCells` is a one-liner wrapping `LookupTables.cellNeighbours`
- **Category**: code quality
- **File**: `Sources/SudokuCore/Hints/HintFinder+Helpers.swift:72-74`
- **Failure mode**: just renaming a lookup. Adds an indirection without value. Used in some techniques.
- **Suggested fix**: replace call sites with `LookupTables.cellNeighbours[position.row][position.column]` and delete the helper. Optional cleanup.

### Hints/HintViewModel.swift

#### [Medium] Hint search runs all 21 techniques in parallel then sorts — defeats easiest-first ordering
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/HintViewModel.swift:43-72`
- **Failure mode**: `withThrowingTaskGroup` schedules all 21 techniques as concurrent child tasks. On a typical mid-game board, naked singles or hidden singles are available — but the executor doesn't know that, so it's running expensive Jellyfish/XYZ-Wing searches in parallel even though the easy hint will be selected anyway. Every hint refresh (after every cell change) does this. On a player solving a 50-action puzzle, that's 50 × 21 = 1050 technique searches, ~half of which are wasted work on hard techniques.
- **Test coverage**: not measured.
- **Suggested fix**: two options:
  - (a) Find only the *next easiest* hint synchronously (already exists as `HintFinder.firstHint`) and surface that. Drop parallelism — hint find on Apple silicon is already <10ms typically.
  - (b) Keep parallel search but cancel sibling tasks as soon as a hint at the easiest difficulty tier returns.
  Option (a) is simpler and matches typical Sudoku UX (one hint at a time).

#### [Medium] `availableHints` exposes ALL technique hints for current state, not just the easiest
- **Category**: API / clarity
- **File**: `Sources/SudokuCore/Hints/HintViewModel.swift:86`
- **Failure mode**: by collecting hints from every technique, `availableHints` includes overlapping/redundant suggestions. A hint UI showing "available hints" might display 4 hints when really there's one obvious next move and 3 deep-pattern alternatives. If the intent is "show which techniques are applicable right now," that's a different feature; if the intent is "show the next hint," only `currentHint` is meaningful and the rest is wasted.
- **Suggested fix**: clarify intent in doc comments. If only `currentHint` is needed, return after first hit. If the breadth is intentional (e.g. for a "technique tutor" UI), document that.

#### [Low] `lookForHints` `Task` retains itself via `currentHintTask` even after completion
- **Category**: memory / lifecycle
- **File**: `Sources/SudokuCore/Hints/HintViewModel.swift:37-83`
- **Failure mode**: `currentHintTask` is set to the new task but never cleared after the task completes. Each successful search leaves a finished `Task` reference. The task itself completes and releases its captures, but the wrapper struct stays in `currentHintTask` until the next `lookForHints()` overwrites it. Not a memory leak in the traditional sense, but spurious retain.
- **Suggested fix**: at the end of the closure, set `await MainActor.run { self?.currentHintTask = nil }`. Or wrap in a `defer` that runs on completion.

#### [Low] `init(board:)` and `init()` start a hint search but don't await it
- **Category**: API
- **File**: `Sources/SudokuCore/Hints/HintViewModel.swift:14-22`
- **Failure mode**: callers can read `availableHints` immediately after init and get an empty array. There's no signal that the first search hasn't completed. Tests asserting "after init, availableHints is non-empty for a partial board" would flake.
- **Suggested fix**: document the async nature in the init doc comment. If callers need synchronous initialisation, expose a `prefetched: Bool = true` parameter that runs the first search synchronously.

### Hints/Hint Implementation/Validation.swift

#### [Low] Doc comment claims "returns immediately on first conflict" but code accumulates all row conflicts before returning
- **Category**: documentation
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/Validation.swift:13-22`
- **Failure mode**: doc says rows are checked first and the function returns "immediately on first conflict." Actually, the row loop (lines 30-49) runs to completion across all 9 rows and accumulates every conflict in `conflictActions`/`conflictCells`, only returning after the loop. Same for column and house loops. The behavior is correct (accumulates all row conflicts, then bails out before checking columns), but the doc lies about the "immediate return."
- **Suggested fix**: update the doc to "Accumulates all conflicts in the first unit type with a violation (rows first, then columns, then houses), and returns those."

#### [Low] Validation `seen[value] = currentIndex` overwrites the original conflict cell on triple+ duplicates
- **Category**: minor correctness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/Validation.swift:46`
- **Code**:
  ```swift
  if let previousIndex = seen[value] { ... }
  seen[value] = Puzzle.Index(row: row, column: col)
  ```
- **Failure mode**: when a row has three or more cells with the same digit (X at columns 1, 4, 7), the second occurrence creates a conflict pair (1, 4), and the third overwrites `seen[X]` with column 7, losing the original column 1 and replacing it with 4 — wait actually `seen[X] = column 4` happens after the conflict is reported, so when col 7 sees `seen[X] = column 4`, the conflict pair becomes (4, 7), and column 1 is no longer reported. With three duplicates, only two of the three cells get added to `conflictCells` (the second and third).
- **Suggested fix**: collect ALL occurrences of a digit per row, not just the most-recent two. Track `seen[value] = [Index]` and on second occurrence add all cells to `conflictCells`. Or, simpler: track `firstSeen[value]` and never overwrite; insert all subsequent occurrences plus the first into `conflictCells`.

### Hints/Hint Implementation/HiddenSingles.swift

#### [Medium] Grammar bug: "This 5 affect" / "These 5's affect"
- **Category**: localization
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSingles.swift:120, 122`
- **Code**:
  ```swift
  text = LocalizedStringResource("This \(digit) affect this \(orientation.displayName)", bundle: .module)
  // ...
  text = LocalizedStringResource("These \(digit)'s affect this \(orientation.displayName)", bundle: .module)
  ```
- **Failure mode**: subject-verb agreement is wrong on the singular branch ("This 5 **affect**" → should be "affects"). Apostrophe-s on the plural branch makes it possessive ("these 5's") instead of plural ("these 5s"). Visible to any user receiving a Hidden Single hint.
- **Test coverage**: `HintExplanationTests` may snapshot exact strings — they would all need updating.
- **Suggested fix**:
  - Singular: `"This \(digit) affects this \(orientation.displayName)"`
  - Plural: `"These \(digit)s affect this \(orientation.displayName)"`
  - Update Localizable.xcstrings keys accordingly. Consider using `inflect:` or grammar agreement once the project supports it.

#### [Low] Step 3 explanation refers to "red cells" — assumes specific UI rendering
- **Category**: localization / UX
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSingles.swift:145`
- **Code**:
  ```swift
  text: LocalizedStringResource("So, the red cells cannot be \(digit).", bundle: .module),
  ```
- **Failure mode**: hard-coded reference to "red cells" assumes the UI renders `.warning` or `.secondary` highlights as red. If a theme uses orange or a colorblind-safe palette, the text becomes nonsensical.
- **Suggested fix**: change to "So, these cells cannot be \(digit)." or "the highlighted cells".

#### [Low] Step 3 highlights the entire unit AND the target cell with conflicting types
- **Category**: UX
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSingles.swift:156-166`
- **Failure mode**: `cellWithDigit.cells(in: orientation)` returns ALL cells in the unit (including `cellWithDigit` itself), and they're all highlighted as `.warning`. But `cellWithDigit` is also separately added with `.primary`. The same cell receives two highlight types in the same step. Whichever one wins depends on UI render order; the result may be confusing.
- **Suggested fix**: filter `cellWithDigit.cells(in: orientation).filter { $0 != cellWithDigit }` before mapping to warning highlights.

### Hints/Hint Implementation/NakedSingles.swift

#### [Low] Step 1 text "This cell only has one candidate" missing trailing period (compare to step 3)
- **Category**: localization consistency
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/NakedSingles.swift:76, 90, 109`
- **Failure mode**: step 1 ("This cell only has one candidate") and step 2 ("...Leaving \(digit) the only remaining option") have no terminal punctuation, while step 3 ("Therefore, this cell must be \(digit).") has a period. Inconsistent across the three steps in one explanation. Cosmetic but visible.
- **Suggested fix**: add periods to steps 1 and 2.

### Hints/Hint Implementation/NakedSubsets.swift

#### [Low] `count <= n` filter accepts cells with fewer candidates than the subset size
- **Category**: efficiency / explanation accuracy
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/NakedSubsets.swift:65`
- **Code**:
  ```swift
  if count > 0 && count <= n {
      cellCandidates.append((position, candidates))
  }
  ```
- **Failure mode**: the elimination is mathematically sound — n candidates confined to n cells must stay there regardless of how many candidates each cell individually has. **However**, the explanation generator says "these N cells in the same unit. Together, they contain only N candidates" (line 172) — but if one of those cells has only 1 candidate (it's already a naked single), it should have been caught earlier. The bigger consequence: when the technique fires for a "naked pair {1,2} + naked single {1}" situation, the resulting hint is logically a hidden naked single, not a naked pair, but it's labeled as `nakedPair`. The difficulty rating and human-style explanation are misleading.
  Naked singles run earlier in `HintTechnique.orderedCases`, so in `firstHint` the single fires first. But `findHint(for: .nakedPair, ...)` directly (used by `HintViewModel`'s parallel search) can return the misclassified hint.
- **Test coverage**: existing tests likely exercise classical naked pairs only.
- **Suggested fix**: change `count <= n` to `count == n`. Cells with fewer candidates are picked up by the matching naked-single/naked-pair tier. Document this rationale in a comment.

#### [Low] `localisedCountName(n)` returns "two/three/four" — used in "these two cells" but also "two candidates"; one is a count, one is plural-noun
- **Category**: localization
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/NakedSubsets.swift:172, 187, 196`
- **Failure mode**: the string uses `\(subsetName)` for both "these \(subsetName) cells" and "\(subsetName) candidates." In English both work since "two" reads naturally as either. In other locales (e.g. languages with grammatical agreement), this won't fly: "two cells" might inflect differently than "two candidates." LocalizedStringResource doesn't support pluralization rules per noun.
- **Suggested fix**: split into two localised tokens and use them separately, or accept this as English-only ergonomic and document.

### Hints/Hint Implementation/HiddenSubsets.swift

#### [Low] `digitToCells: [Set<Puzzle.Index>]` is a 10-element array of Sets — most are tiny or empty
- **Category**: micro-perf
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSubsets.swift:50`
- **Failure mode**: ten Set allocations per unit per call. With 27 units that's 270 set allocations for a single hidden-subset search. Sets of ≤3 elements should fit in a small inline buffer; using `[Puzzle.Index]` and converting at use would avoid the allocations.
- **Suggested fix**: use `[[Puzzle.Index]]` indexed by digit; convert to Set only at union step.

#### [Low] `removals.reserveCapacity(unionCells.count * 6)` over-reserves substantially
- **Category**: micro-perf
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSubsets.swift:111`
- **Failure mode**: `unionCells.count == n` (max 4), and each cell can have at most `9 - n` other candidates. So the upper bound is `4 * (9 - 4) = 20` for a quad. Reserving `n * 6 = 24` for a quad and only 12 for a pair is approximately right, but the formula is unclear.
- **Suggested fix**: comment the formula or replace with `n * (9 - n)`.

### Hints/Hint Implementation/LockedPointing.swift

#### [Low] `cellsInHouse.first!` force-unwrap relies on caller invariant
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/LockedPointing.swift:182, 201`
- **Failure mode**: `cellsInHouse` is `possiblePositions`, which is non-empty only because the entry condition (line 52) requires `possiblePositions.count > 0`. Force-unwrap is safe today but fragile if someone refactors entry conditions.
- **Suggested fix**: replace `cellsInHouse.first!` with a guard at the function entry (`guard let representative = cellsInHouse.first else { return [] }`).

### Hints/Hint Implementation/FishPatterns.swift

#### [Medium] Finned fish accepts up to `n + 2` cross lines, which permits "Sashimi Sashimi" patterns not standard finned fish
- **Category**: correctness / classification
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/FishPatterns.swift:333`
- **Code**:
  ```swift
  } else if allCrossLines.count > n && allCrossLines.count <= n + 2 {
  ```
- **Failure mode**: standard "finned fish" has exactly `n + 1` cross lines (one fin); `n + 2` admits two-fin patterns that some references call "Sashimi" or "doubly finned" and are typically classified as harder techniques. The classification still uses `finnedXWing/Swordfish/Jellyfish` regardless, so a doubly-finned X-Wing gets the same difficulty as a single-fin one. Difficulty ratings are slightly off for these cases.
- **Test coverage**: depends on whether tests exercise `n+2` cases distinctly.
- **Suggested fix**: either restrict to `n + 1` (canonical), or add separate enum cases (`.sashimiXWing` etc.) with their own difficulty values.

#### [Medium] `detectFins` ambiguous-tie path tries up to C(k, n) combinations — unbounded for high tied-frequency cases
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/FishPatterns.swift:117-135`
- **Failure mode**: when many cross lines have the same frequency count, `combinations(of: crossLinesArray, choose: n)` enumerates all C(k, n). For n=4 and k=8, that's 70 combinations. For each combination, `validateFins` runs a full scan over base lines × cross lines + same-box check + elimination scan. Worst-case multiplier is ~70× the standard path on jellyfish. In practice, ties are rare; under unusual board states this becomes a noticeable slowdown.
- **Suggested fix**: add an early-exit on the first valid partition (already there). Add a count-based heuristic so cells in clearly-coreward positions are tried first. Document the worst-case complexity in the function doc.

#### [Low] `fishTechnique` fatalErrors on n outside 2-4
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/FishPatterns.swift:24, 31`
- **Failure mode**: defensive crash on a private function. Callers always pass 2/3/4. If a future refactor adds size 5 (Squirmbag) without updating this switch, the binary will trap.
- **Suggested fix**: replace with `assertionFailure` and a sensible default (e.g. nearest valid technique), or constrain `n` via an enum at the type level.

### Hints/Hint Implementation/WingPatterns.swift

#### [Medium] `validateXYZWing` doesn't enforce `pivot.count == 3`; permissive though pivot pre-selection masks the bug
- **Category**: correctness / robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:309-323`
- **Failure mode**: pivots are filtered to `count == 3` at the call site (line 80, 92-93), so this isn't observable today. But the validator alone would accept pivots with 4+ candidates that satisfy the loose subset constraints, producing eliminations that are NOT actually XYZ-Wing-justified. A future refactor that calls the validator from a different entry point could trigger over-elimination.
- **Suggested fix**: add `guard pivot.count == 3 else { return nil }` at the top of `validateXYZWing`. Same for `validateXYWing`/`validateYWing` (require pivot.count == 2).

#### [Low] XY-Wing `validateXYWing` has duplicate logic with `validateYWing`
- **Category**: code quality
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:239-296`
- **Failure mode**: the two functions are nearly identical — both check pivot ∩ wingA = 1 and pivot ∩ wingB = 1, distinct, and wings share an elimination digit. The doc says XY-Wing is "strict" and Y-Wing is "relaxed," but the actual code paths look identical. Verify whether they should be merged or whether the relaxation was lost in a refactor.
- **Suggested fix**: read the original Y-Wing definition. If they should differ, fix Y-Wing to the relaxed variant. If they're equivalent, alias one to the other and clarify in docs that this codebase treats them as synonyms.

#### [Low] Wing pattern force-unwraps `wingA.subtracting([x]).first!`
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:257-258, 292-293`
- **Failure mode**: relies on wing being a 2-element set so subtraction yields a 1-element set. If wingA is a 3-candidate cell (which the call site filters out, but defensively), the subtraction could return 2 elements and `.first` is non-deterministic.
- **Suggested fix**: explicitly check `guard wingA.count == 2, wingB.count == 2 else { return nil }` at the top of validators.

### Hints/Hint Implementation/WWing.swift

#### [Low] W-Wing builds a full strong-link table per call across all digits and units (≈ 27 × 9 × 9)
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WWing.swift:38-83`
- **Failure mode**: every call rebuilds `strongLinks` from scratch (rows × 9 × 9 + columns × 9 × 9 + boxes × 9 cells). This is O(27 × 81) = 2187 operations per W-Wing search. The same data is rebuilt by Skyscraper, Two-String Kite, and Empty Rectangle — each technique computes its own strong-link table. Caching strong links once per `BoardState` would amortise the cost across all chain techniques.
- **Suggested fix**: add `lazy var strongLinks: [Int: [(Puzzle.Index, Puzzle.Index)]]` to BoardState (or a separate solver-state struct), computed once and reused. Significant win when running multiple chain-style techniques in a row.

### Hints/Hint Implementation/Skyscraper.swift

#### [Low] Skyscraper uses `combinations(of: crossLines1, choose: 2)` on a known-2-element list
- **Category**: code quality / micro-perf
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/Skyscraper.swift:94-95`
- **Failure mode**: each `crossLines1` and `crossLines2` has exactly 2 elements (filter at line 74). C(2, 2) = 1 — there's only one pair, which is the array itself. The combinations call generates a single 2-element subarray, which is then iterated over. Wasted setup.
- **Suggested fix**: replace with direct use: `let pair1 = crossLines1` and skip the `pairs1` collection entirely.

### Hints/Hint Implementation/EmptyRectangle.swift

#### [Low] `findEmptyRectangle` iterates `for erRow in candidateRows` and `for erCol in candidateCols` — multiple (erRow, erCol) pairs may be valid, but only the first is returned
- **Category**: correctness / completeness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/EmptyRectangle.swift:53-83`
- **Failure mode**: iteration order over a Set is unspecified, so the (erRow, erCol) pair the function returns is non-deterministic across runs. If multiple valid ER configurations exist within one box, results may differ between sessions or test runs. Tests may flake.
- **Suggested fix**: sort `candidateRows` and `candidateCols` before iterating, or accept the first deterministic-by-row-order pair.

### Hints/Hint Implementation/TwoStringKite.swift

#### [Low] Strong-link tables (rowLinks/colLinks) rebuilt per digit per call
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/TwoStringKite.swift:25-52`
- **Failure mode**: same as the WWing finding — strong-link computation is duplicated across techniques. See the suggested cached structure.

### Board/Board+Marking.swift

#### [Medium] `apply(hint:)` produces fragmented undo history (one save per action)
- **Category**: correctness / UX
- **File**: `Sources/SudokuCore/Board/Board+Marking.swift:214-238`
- **Code**:
  ```swift
  public func apply(hint: HintStep) {
      hintsUsed += 1
      for action in hint.actions {
          switch action.action {
          case .clear: clearCell(at: [action.position])
          case .pencilIn(let value): pencil(positions: [action.position], as: value)
          case .ruleOut(let value): ruleOut(positions: [action.position], as: value)
          case .solveAs(let value): mark(positions: [action.position], as: value)
          }
      }
      updateCellValidation()
  }
  ```
- **Failure mode**: each helper (`clearCell`, `pencil`, `ruleOut`, `mark`) calls `saveState()` internally. A hint with three actions creates three undo steps. From the user's perspective, undoing a hint takes three undo presses with intermediate states that don't correspond to any decision the user made. For chain techniques (XYZ-Wing eliminations across 4-5 cells), this is especially confusing.
- **Test coverage**: `BoardUndoRedoTests` may not cover hint application specifically.
- **Suggested fix**: introduce internal versions of the helpers that skip `saveState()`. Have `apply(hint:)` call `saveState()` once before the loop and use the internal helpers within. Alternative: capture state before the loop, call helpers, then collapse all intermediate undo steps back into a single one.

#### [Low] `color()` calls `saveState()` AFTER mutation; other methods save BEFORE
- **Category**: code quality / consistency
- **File**: `Sources/SudokuCore/Board/Board+Marking.swift:161-177`
- **Failure mode**: every other mutating method saves the pre-mutation state so undo restores it. `color` saves the post-mutation state, meaning undoing color either does nothing or rolls back something prior. Either a real bug or the comment-doc is wrong.
- **Suggested fix**: verify intent. If color should be undoable, move `saveState()` to before the loop. If color is intentionally non-undoable (visual-only), document and skip undo handling entirely.

#### [Low] `pencil()`/`advancedPencil()` use `allSatisfy` on a possibly-empty filtered collection
- **Category**: edge case
- **File**: `Sources/SudokuCore/Board/Board+Marking.swift:100-104, 133-137`
- **Failure mode**: `allSatisfy` returns `true` for empty collections. If all selected positions have non-nil values (i.e., filter eliminates everything), `remove == true` (vacuously). The inner `where cell(at: position).value == nil` then short-circuits the loop, so no harm. But if the selected cells have empty pencil-mark sets, `remove == true` and the function takes the wrong branch.
- **Suggested fix**: explicitly handle the empty case: `let nonEmpty = ...; let remove = nonEmpty.isEmpty == false && nonEmpty.allSatisfy { $0.contains(value) }`.

### Board/Board+Validation.swift

#### [High] `incorrectMoves` increments on every `updateCompletedSets` call when the board has any inconsistency
- **Category**: correctness
- **File**: `Sources/SudokuCore/Board/Board+Validation.swift:55-58`
- **Code**:
  ```swift
  isSolvable = matchesSolution
  if isSolvable == false {
      incorrectMoves += 1
  }
  ```
- **Failure mode**: `updateCompletedSets` is called after every `mark`, `pencil`, `clearCell`, etc. After the user makes one wrong move, `isSolvable` flips false. Every subsequent action (even correct ones elsewhere) re-runs the check, sees `isSolvable == false`, and bumps `incorrectMoves` again. The counter inflates monotonically until the wrong cell is corrected. PerformanceScoreCalculator uses `errorCount` as input — one mistake then completing the puzzle yields `errorCount` ≈ number of post-mistake actions instead of 1.
- **Test coverage**: BoardValidationTests should catch this; verify whether the count is asserted across multiple actions.
- **Suggested fix**: only increment on transitions from solvable to unsolvable:
  ```swift
  let wasSolvable = self.isSolvable
  self.isSolvable = matchesSolution
  if wasSolvable && self.isSolvable == false {
      incorrectMoves += 1
  }
  ```
  Better: derive `incorrectMoves` from the count of cells with `value != nil && value != correctAnswer` and recompute on each update — no double-counting possible.

#### [Low] `updateCompletedSets` sets `isSolved = true` on line 45, then re-evaluates on lines 126-130
- **Category**: code quality / dead code
- **File**: `Sources/SudokuCore/Board/Board+Validation.swift:42-130`
- **Failure mode**: line 45 conditionally sets `isSolved = true` if `grid == solution`. Lines 126-130 re-evaluate via `Validator.isCompleteAndValidSolution` and overwrite. The first assignment is wasted; the validator is the source of truth.
- **Suggested fix**: remove the `grid == solution` check at lines 44-45 (the validator covers it).

#### [Low] `updatePencilMarks` always increments `noteUpdates` even when no marks change
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Board/Board+Validation.swift:17-27`
- **Failure mode**: toggling `autoPencilMode` on/off bumps `noteUpdates` every time. PerformanceScoreCalculator's "no assistance bonus" uses `noteUpdates` as a player-engagement signal — auto-pencil shouldn't count.
- **Suggested fix**: only increment `noteUpdates` when at least one cell's `simplePencilMarks` actually changed AND the change was player-driven (not auto-pencil).

#### [Low] `eliminatePencilMarks` and `updatePencilMarks` overlap in behaviour without clear semantics
- **Category**: code quality
- **File**: `Sources/SudokuCore/Board/Board+Validation.swift:17-38`
- **Failure mode**: `updatePencilMarks` overwrites `simplePencilMarks` with the full validOptions; `eliminatePencilMarks` only intersects existing marks with validOptions. The names don't make the difference clear, and one increments `noteUpdates` while the other doesn't.
- **Suggested fix**: rename for clarity (`fillAllValidPencilMarks` vs `pruneInvalidPencilMarks`). Document the noteUpdates contract for each.

### Board/Board+Helpers.swift

#### [Low] `cellPositions(with:)` uses `filter` then `reduce(into: Set)`; cleaner with `Set(compactMap)`
- **Category**: code quality
- **File**: `Sources/SudokuCore/Board/Board+Helpers.swift:41-45`
- **Suggested fix**: `Set(cells.lazy.compactMap { $0.value == number ? $0.position : nil })`.

#### [Low] `allHouses` rebuilds the 9-house list with O(81×9) "already-in-another-house" check on every access
- **Category**: performance
- **File**: `Sources/SudokuCore/Board/Board+Helpers.swift:17-26`
- **Failure mode**: 81 cells × up-to-9 housed × 9 contains-check = ~6500 comparisons per call. Used in tests but not hot paths; still wasteful.
- **Suggested fix**: replace with `LookupTables.boxCells.map { $0 }` (already precomputed).

### Board/Board+UndoRedo.swift

#### [Medium] No redo capability — only undo is implemented
- **Category**: feature gap
- **File**: `Sources/SudokuCore/Board/Board+UndoRedo.swift` (entire file)
- **Failure mode**: file is named `Board+UndoRedo.swift` but only `undo()`, `undo(to:)`, `recoverToLastCorrectState()`, `makeCheckpoint()`, and `saveState()` exist. There is no `redo()` and no `redoStack`. A player who undoes and wants to restore cannot.
- **Test coverage**: not tested because not implemented.
- **Suggested fix** (if redo is wanted): add `private var redoStack: [UndoStep]`. On `undo()`, push the popped state onto `redoStack`. On any state-mutating action, clear `redoStack`. Add `redo()` that pops `redoStack`. Update `BoardRestoration` to include both stacks. Confirm with the user whether redo is in scope before adding.

#### [Medium] `saveState()` does an O(81) array equality check on every action
- **Category**: performance
- **File**: `Sources/SudokuCore/Board/Board+UndoRedo.swift:61-65`
- **Failure mode**: every mutation triggers `saveState()`, which compares 81 `Cell` structs (each with position, value, 4 sets, Background, UUID, correctAnswer). Equality cascades through every property. Hot in the per-keystroke path.
- **Suggested fix**: track a `dirty: Bool` flag set true on any mutation and reset on saveState push. Or compare a precomputed hash of relevant cell state.

#### [Low] `recoverToLastCorrectState` swallows errors via `print(error)` and continues
- **Category**: error handling / logging
- **File**: `Sources/SudokuCore/Board/Board+UndoRedo.swift:43-54`
- **Failure mode**: `undo(to:)` errors are printed and the loop continues. Caller has no way to detect that recovery failed. Also `print` violates the user instruction "I prefer to use logs instead of print" (per CLAUDE.md).
- **Suggested fix**: use structured logging (`os_log`/Logger). Either propagate the error or report a recovery-failure status.

### Board/Board+StateRestoration.swift

#### [Medium] `restore` overwrites given cells from `currentState` without an isGiven check
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Board/Board+StateRestoration.swift:85-94`
- **Failure mode**: when `value != 0`, the cell's value is overwritten regardless of `isGiven`. If persisted `currentState` differs from the original given values (corruption, schema drift, loaded from a different puzzle), restoration silently mutates given cells. `isValid` doesn't check given-cell integrity, so the corruption goes unnoticed downstream.
- **Suggested fix**: only assign if the cell isn't given OR the value matches the given value. Throw a `BoardRestorationError.givenCellMismatch` if a given cell would change.

#### [Low] `BoardRestoration.elapsedTime` is stored but never used by `Board`
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Board/Board+StateRestoration.swift:50-75, 77-121`
- **Failure mode**: `BoardRestoration` carries an `elapsedTime` field. The legacy `restore(...)` overload hardcodes it to 0. The newer `restore(_ restoration:)` reads `restoration.elapsedTime` but never assigns it anywhere — Board has no `elapsedTime` property. The field is ingested but discarded.
- **Suggested fix**: either add an `elapsedTime` stored property on Board (with a starting timestamp) and persist it through restore, or remove `elapsedTime` from `BoardRestoration` to stop pretending it's tracked.

#### [Low] `currentGrid`/`startingGrid`/`simplePencilMarks`/`advancedPencilMarks`/`ruledOutCandidates`/`backgroundColors` rebuild 9×9 arrays on every access
- **Category**: performance
- **File**: `Sources/SudokuCore/Board/Board+StateRestoration.swift:141-223`
- **Failure mode**: each is `Array(0..<9).map { row in Array(0..<9).map { col in cell(at: ...).property } }` — 2 outer arrays + 81 cell lookups per call. `Board.state` (Hints/Board+State.swift:30) calls `self.currentGrid` AND maps cells separately, so a single `Board.state` access is 2 of these properties + 81-cell loop. Hint search triggers `Board.state`; on every keystroke this compounds.
- **Suggested fix**: have `Board.state` traverse cells once and pull all needed values inline (no intermediate properties). Or cache these in stored arrays invalidated on mutation.

### Board/Cell.swift

#### [Low] `Array<Board.Cell>.solution` is named misleadingly — it returns the current grid, not the puzzle solution
- **Category**: API / naming
- **File**: `Sources/SudokuCore/Board/Cell.swift:128-143`
- **Failure mode**: `cells.solution` returns a 9×9 grid of currently-placed values (zeros for empty). `Puzzle.solution` is the actual answer. Reading `board.cells.solution` and expecting the answer is a foot-gun.
- **Suggested fix**: rename to `currentGrid` or `placedValues`. Add a deprecated alias.

#### [Low] `flatString(empty:)` is implemented twice — Cell array vs Solution
- **Category**: code duplication
- **File**: `Sources/SudokuCore/Board/Cell.swift:174-184` and `Sources/SudokuCore/CoreModels/Solution.swift:51-58`
- **Suggested fix**: have `Array<Cell>.flatString` delegate to `cells.solution.flatString(empty:)`.

#### [Low] `Array<Cell>.diff(from:)` traps on duplicate UUIDs (`Dictionary(uniqueKeysWithValues:)`)
- **Category**: robustness
- **File**: `Sources/SudokuCore/Board/Cell.swift:197`
- **Failure mode**: cells receive fresh UUIDs on init, so duplicates are essentially impossible. But malformed Codable decoding could produce duplicates and the trap would crash with an unhelpful "duplicate key" message.
- **Suggested fix**: use `Dictionary(_:uniquingKeysWith:)` with `{ $1 }` to keep the latest, or use position-based keys instead of UUIDs.

### Board/CellBackground.swift

#### [Low] `Background.init(from:)` force-unwraps `init(rawValue:)`
- **Category**: robustness
- **File**: `Sources/SudokuCore/Board/CellBackground.swift:25`
- **Failure mode**: today the input is constrained (0 handled separately, then `min(abs(number), 9)` produces 1-9, all valid). Safe. But fragile: removing `abs` would break the contract silently.
- **Suggested fix**: `self = Background(rawValue: min(abs(number), 9)) ?? .clear`.

### Board/Board.swift

#### [Low] `SetUp` is named in PascalCase (Swift convention is camelCase)
- **Category**: naming
- **File**: `Sources/SudokuCore/Board/Board.swift:230`
- **Suggested fix**: rename to `setUp` with a deprecated alias.

#### [Low] `Puzzle.Index.linerIndex` typo — should be `linearIndex`
- **Category**: naming
- **File**: `Sources/SudokuCore/Board/Board.swift:272-276`
- **Failure mode**: 7+ usages across Board code spell `linerIndex` ("liner-index"). Should be `linearIndex`.
- **Suggested fix**: rename with a deprecated alias.

### Board/Board+Checking.swift

#### [Low] `Board.isValid` doesn't verify given cells are unchanged
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Board/Board+Checking.swift:10-12`
- **Failure mode**: `isValid` only checks for unit conflicts. If a given cell is corrupted to a non-conflicting value (e.g., via the BoardStateRestoration finding above), `isValid` still returns true. Defense in depth would catch the corruption here.
- **Suggested fix**: add an integrity check that given cells still match their original values. Either store the original given snapshot on Board or recompute by comparing `cell.value` against the puzzle's startingState.

#### [Low] `rowDigits`, `columnDigits`, `houseDigits` are private but never called
- **Category**: dead code
- **File**: `Sources/SudokuCore/Board/Board+Checking.swift:16-43`
- **Failure mode**: confirmed unused; 30 lines of dead code.
- **Suggested fix**: delete.

### Rating/HoDoKuCalculator.swift

#### [Medium] `compute(from:)` adds a `1.0 + 0.05 * eliminations` modifier — non-canonical HoDoKu
- **Category**: correctness / semantics
- **File**: `Sources/SudokuCore/Rating/HoDoKuCalculator.swift:31-33`
- **Code**:
  ```swift
  let base: Double = step.technique.hodokuPoints
  let modifier = 1.0 + 0.05 * Double(step.eliminations)
  let points = Int((base * modifier).rounded())
  ```
- **Failure mode**: HoDoKu's published rating sums fixed per-technique points without per-step modifiers. The 5%-per-elimination bump means the same puzzle scored via two different solve paths (e.g., one technique fires twice with 1 elimination each vs one step with 2 eliminations) yields different ratings. The class label `"HoDoKu"` and field name `hodokuRating` therefore mislead downstream consumers who interpret the value as a published HoDoKu rating.
- **Test coverage**: `HoDoKuCalculatorTests` likely encodes this modified behaviour as expected. Worth re-checking against canonical HoDoKu.
- **Suggested fix** (decision required): either (a) drop the modifier and update tests to match canonical HoDoKu values; or (b) keep the modifier, rename the calculator/result to make it clear this is a custom variant (`SudokuCoreEffortCalculator`?) and document the deviation. Don't ship something called HoDoKu that isn't.

#### [Low] `classify(rating:)` searches `classThresholds` linearly each call
- **Category**: micro-perf / code quality
- **File**: `Sources/SudokuCore/Rating/HoDoKuCalculator.swift:43-48`
- **Failure mode**: 5 thresholds, sequential scan. Negligible cost. But the early termination assumes `classThresholds` is sorted by `maxPoints` ascending — if someone reorders the table it silently breaks. No assertion or sort-on-init.
- **Suggested fix**: either sort defensively in the function or document the requirement.

### Rating/SECalculator.swift

#### [Low] When path is empty, `hardestTechniqueName` is `"None"` and `rating` is 0 — silently classifies as easiest
- **Category**: edge case
- **File**: `Sources/SudokuCore/Rating/SECalculator.swift:41-51`
- **Failure mode**: an empty path (no steps required, e.g., already-solved grid) yields rating 0.0. Callers using SE rating to gate puzzle inclusion may treat 0.0 as "easiest puzzle ever" rather than "no work to do."
- **Suggested fix**: surface a sentinel (`rating: nil` if `SEResult.rating` becomes `Double?`, or `hardestTechniqueName: "Empty"`) and document.

#### [Low] `seStepValue` for `xyWing` is 4.5 but `xyzWing` is 5.2; difference is small while `difficulty` integers (110, 120) suggest a 9% gap
- **Category**: rating-table calibration
- **File**: `Sources/SudokuCore/Hints/Hints.swift:122-149`
- **Failure mode**: the SE step values were transcribed from somewhere — but with no documented source. If they were tuned against actual SudokuExplainer output, fine; if they were guesses, the SE rating's claim to be "Sudoku Explainer-style" is shaky.
- **Suggested fix**: either cite the source for these values in a comment, or run a calibration pass against canonical SE output and update.

### Rating/RatingTables.swift

#### [Low] `RatingTables.TimeMapping.logModel = (2.0, 2.2)` is uncited
- **Category**: documentation / fragility
- **File**: `Sources/SudokuCore/Rating/RatingTables.swift:28`
- **Failure mode**: the linear-in-log model is `minutes = 2.0 + 2.2 * log(rating)`. At rating 100, that's ~12 min; rating 600, ~16 min; rating 2000, ~19 min. Compare to `PerformanceScoreCalculator.calculateTargetTime` which gives 15 min at rating 600 and 90 min at rating 2000. The two models disagree by a factor of ~5 at the high end. Either the time models are inconsistent with each other (a real bug — performance scoring expects very different times than time estimation), or `logModel` is a "minimum baseline" rather than "expected time."
- **Suggested fix**: align the two models, or document explicitly that `RatingTables.TimeMapping.logModel` is for a different purpose than `PerformanceScoreCalculator.calculateTargetTime`. Cite sources.

#### [Low] `classRangesMinutes` uses string keys that drift from `PuzzleDifficulty.Level` enum cases
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Rating/RatingTables.swift:31-38`
- **Failure mode**: `["Basic", "Easy", "Moderate", "Hard", "Very Hard", "Extreme"]` doesn't match the enum cases (`.easy, .medium, .hard, .expert, .professional, .custom`) or the `debugDescription` mapping (`Beginner / Intermediate / Advanced / Expert / Master / Custom`). String lookup can silently miss.
- **Suggested fix**: change the keys to either `PuzzleDifficulty.Level` (Hashable enum) or use the same strings as `Level.debugDescription`. Pick one.

### Rating/SolvePathEmitter.swift

#### [Medium] `emit` returns `solved: false` on `maxIterations` cap without distinguishing "unsolvable" from "exceeded our hint repertoire"
- **Category**: correctness / API
- **File**: `Sources/SudokuCore/Rating/SolvePathEmitter.swift:44-69`
- **Failure mode**: the loop bails out when:
  - The state is solved (`isSolved == true`), or
  - `iterations > maxIterations`, or
  - `HintFinder.firstHint(in: state)` returns nil.
  The caller can only tell from `solved` (true/false) and `iterationCount`. They can't distinguish "puzzle has multiple solutions / is genuinely unsolvable" from "puzzle requires techniques we haven't implemented" from "infinite loop hit the cap." Downstream `SudokuDifficultyCalculator` then falls back to the AC solver and patches up `wasSolved` — but the rating and difficulty class are computed only from the partial path.
- **Test coverage**: `SolvePathEmitterTests` likely covers solved cases.
- **Suggested fix**: change the return signature to include a `reason`:
  ```swift
  enum CompletionReason { case solved, noHint, iterationCap }
  public struct SolvePath { ...; public let reason: CompletionReason }
  ```
  This lets `SudokuDifficultyCalculator` make smarter fallback decisions (e.g., if `reason == .noHint`, the puzzle requires advanced techniques — bump the rating; if `reason == .iterationCap`, log a warning).

### Rating/PersonalizedCalibrator.swift

#### [Low] Sample storage hard-clamps factors to `[minFactor, maxFactor]` (default 0.2 - 4.0) without recording the truncation
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Rating/PersonalizedCalibrator.swift:90-101`
- **Failure mode**: a player who solves an easy puzzle in a fifth of the baseline time has a `raw` factor of 0.2 — at the clamp boundary. Truly fast solves (raw < 0.2) are silently capped to 0.2. Over time, the calibrator's predictions skew toward the cap without indicating that real performance is outside its modelled range. The user just sees "expected: 8 min, you took 1.5 min, factor: 0.2" repeatedly.
- **Suggested fix**: track `clampedSampleCount` separately, or use winsorization at the prediction stage (Tukey fences) instead of hard truncation at the storage stage. At minimum, document the clamping behaviour.

#### [Low] `update` evicts the oldest sample by O(n) min-search instead of O(1) deque pop
- **Category**: performance
- **File**: `Sources/SudokuCore/Rating/PersonalizedCalibrator.swift:95-100`
- **Failure mode**: each update past `maxSamples` finds the minimum-timestamp sample by iterating all samples (O(n)). With `maxSamples: 100` and frequent updates, that's 100 comparisons per call. A circular buffer or sorted-by-timestamp structure would be O(1) eviction.
- **Suggested fix**: either keep `samples` sorted by timestamp at insert time (it usually is, since timestamps are monotonic) and `removeFirst()`, or use `Deque` from swift-collections.

#### [Low] `mad` returns 0 for fewer than 3 values — predict's range collapses to ±0% spread
- **Category**: edge case
- **File**: `Sources/SudokuCore/Rating/PersonalizedCalibrator.swift:171-178`
- **Failure mode**: with 1-2 samples, `mad` is 0; the `spreadFactor = max(0.125, 0)` falls back to 12.5%. With 3+ samples in a window, the MAD-based spread takes over. The transition is silent — early-game predictions have hard-coded 12.5% spread; later predictions use empirical spread. Tests would need to cover both regimes.
- **Suggested fix**: document the transition. Optionally tune the n=3 threshold.

### Rating/TimeEstimator.swift

#### [Low] `baselineSeconds` uses uncited log-linear coefficients
- **Category**: documentation
- **File**: `Sources/SudokuCore/Rating/TimeEstimator.swift:20-25`
- **Failure mode**: same as the RatingTables finding above — the (2.0, 2.2) coefficients are unsourced.
- **Suggested fix**: cite or recalibrate.

#### [Low] `estimate` clamps `userSpeedFactor` to `[0.4, 2.5]` — narrower than `PersonalizedCalibrator`'s `[0.2, 4.0]`
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Rating/TimeEstimator.swift:30-34`
- **Failure mode**: two related estimators clamp at different ranges. A user with a real factor of 0.3 has it clamped to 0.4 here but accepted at 0.3 in the calibrator. Predictions disagree.
- **Suggested fix**: factor out a shared clamping range constant. Or document why they differ.

### Rating/TechniqueMapping.swift

#### [Low] `TechniqueMapping.seId/hodokuId` are pure forwarders that just return `technique.seId`/`technique.hodokuId`
- **Category**: code quality
- **File**: `Sources/SudokuCore/Rating/TechniqueMapping.swift:13-21`
- **Failure mode**: this whole namespace exists to delegate two calls. The doc comments suggest these will be "table-driven" later. If that's not landing soon, the indirection is dead weight.
- **Suggested fix**: either implement the table-driven mapping or remove the forwarder and call `technique.seId` / `technique.hodokuId` directly.

### Models/PuzzleManifest.swift

#### [Low] `PuzzleManifest` hard-codes the difficulty levels — adding a new level requires a struct change
- **Category**: API rigidity
- **File**: `Sources/SudokuCore/Models/PuzzleManifest.swift:11-30`
- **Failure mode**: each `PuzzleDifficulty.Level` (except `.custom`) has a dedicated property and a switch case in `batchPaths(for:)`. If you add a new level, you must update Codable keys, the init, every accessor, and `allBatchPaths`. The model couples tightly to the enum.
- **Suggested fix**: change the storage to `[PuzzleDifficulty.Level: [String]]`. That requires custom Codable to preserve JSON shape (or migrate the JSON). Trade-off: less ceremony when levels change, but breaks JSON wire compatibility.

#### [Low] Deprecated `batchURLs` and `allBatchURLs` silently drop entries on `URL(string:)` failure
- **Category**: data integrity
- **File**: `Sources/SudokuCore/Models/PuzzleManifest.swift:47-66`
- **Failure mode**: a malformed URL string in the manifest is dropped without warning. The deprecated APIs are presumably going away — but until they do, callers may receive fewer URLs than expected.
- **Suggested fix**: since these are deprecated, no action needed. If they're staying, log dropped strings.

### Models/PuzzleServerConfig.swift

#### [Low] `baseURL` is a `String` and URL construction silently fails if the string is malformed
- **Category**: API
- **File**: `Sources/SudokuCore/Models/PuzzleServerConfig.swift:10-22`
- **Failure mode**: `manifestURL` returns `URL?`, returning nil on construction failure. Callers must handle nil, but the failure mode is silent. There's no validation at config init.
- **Suggested fix**: validate at init — `precondition(URL(string: baseURL) != nil)` — or store a `URL` directly. The current shape forces every call site to handle nil.

#### [Low] `baseURL` has trailing-slash sensitivity
- **Category**: robustness
- **File**: `Sources/SudokuCore/Models/PuzzleServerConfig.swift:21, 27, 37`
- **Failure mode**: URLs are constructed with `"\(baseURL)/\(version)/manifest.json"`. If `baseURL` has a trailing slash, the result has `//` in it. If it doesn't, the result is fine. URL parsers usually handle `//` but not always.
- **Suggested fix**: normalise at init — strip a trailing slash if present.

#### [Low] `production` config exposes a R2 dev domain in source
- **Category**: deployment / privacy
- **File**: `Sources/SudokuCore/Models/PuzzleServerConfig.swift:42-44`
- **Failure mode**: the public R2 URL is committed to source. The comment notes it's "until magic-sudoku.app is configured." Hard-coding production endpoints in source ties releases to deployment changes — moving the bucket means a code change.
- **Suggested fix**: move to a build-time configuration (Info.plist, env var, or external config file). At minimum, document the migration plan in code or a TODO.

### Models/MonthlyPuzzleManifest.swift

#### [Medium] Timezone mismatch — `daysInMonth` uses UTC; date parsing/formatting uses `TimeZone.current`
- **Category**: correctness
- **File**: `Sources/SudokuCore/Models/MonthlyPuzzleManifest.swift:62-63` (UTC) and `97, 111, 127, 146` (current)
- **Failure mode**: `daysInMonth` builds a UTC calendar to count days. `DailyPuzzleEntry`'s `dateString`, `init?(dateString:)`, encode/decode all use `TimeZone.current`. A user in UTC+12 fetching a manifest at 23:00 local on the last of the month sees a date that rolls into the next month under `TimeZone.current`'s parsing, but `daysInMonth` (UTC) returns the count for the original month. The `isComplete` check can then fail or pass spuriously.
- **Test coverage**: depends on whether tests run in non-UTC timezone (CI may not).
- **Suggested fix**: pick UTC consistently across both. Manifests are server-side data, so UTC is the natural choice.

#### [Low] `TimeZone(secondsFromGMT: 0)!` force-unwrap
- **Category**: robustness
- **File**: `Sources/SudokuCore/Models/MonthlyPuzzleManifest.swift:63`
- **Failure mode**: `TimeZone(secondsFromGMT: 0)` always returns non-nil on Apple platforms; force-unwrap is safe today but a brittle expression for future-proofing.
- **Suggested fix**: hoist to a module-level `static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt` or use `.gmt` directly (iOS 16+).

#### [Low] `puzzle(for date:)` uses `Calendar.current.isDate(_:inSameDayAs:)`, while month boundaries elsewhere use UTC
- **Category**: correctness
- **File**: `Sources/SudokuCore/Models/MonthlyPuzzleManifest.swift:25-29`
- **Failure mode**: `Calendar.current` follows the device timezone. If puzzles are keyed by UTC dates server-side and the device is east of UTC, "today" on the device may not match the puzzle's "today" UTC, so the function returns nil for the right-now puzzle.
- **Suggested fix**: use a UTC calendar consistently for date comparisons inside the manifest.

#### [Low] `DailyPuzzleEntry`'s manual Codable + `dateString` recomputes a `DateFormatter` per call
- **Category**: performance
- **File**: `Sources/SudokuCore/Models/MonthlyPuzzleManifest.swift:108-150`
- **Failure mode**: every `dateString` access, every `init?(dateString:)`, every encode/decode constructs a fresh `DateFormatter`. `DateFormatter` instantiation is expensive (locale lookup, format parsing). Decoding a 31-day manifest creates 31 formatters at minimum.
- **Suggested fix**: cache a `static let formatter = ISO8601DateFormatter()` configured once. Or use `Date.ISO8601FormatStyle` (iOS 15+) which is value-type and cheap.


---

## Tests/SudokuCoreTests findings

### Board/BoardUndoRedoTests.swift

#### [Low] Test named `testMultipleUndoRedo` only exercises undo — there is no redo to test
- **Category**: misleading test
- **File**: `Tests/SudokuCoreTests/Board/BoardUndoRedoTests.swift:48-78`
- **Failure mode**: the test name suggests undo+redo cycles, but the body only undoes twice. Reading the suite alone, you'd think redo is covered. It isn't (because no redo function exists — see Source finding).
- **Suggested fix**: rename to `testMultipleUndoOperations`. If/when redo is added, add a real `testMultipleUndoRedo`.

#### [Low] No test covers undo of a `clearCell` action separately from `mark`
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Board/BoardUndoRedoTests.swift`
- **Failure mode**: Board has multiple state-mutating methods (`mark`, `clearCell`, `pencil`, `advancedPencil`, `ruleOut`, `color`). The undo tests only exercise `mark`. If `color()`'s saveState placement is wrong (see related Source finding), this suite would not catch it.
- **Suggested fix**: add per-method undo tests covering each mutator.

### Board/BoardValidationTests.swift

#### [High] No test asserts the `incorrectMoves` counter behavior across multiple actions
- **Category**: coverage gap (lets the "incorrectMoves inflates" Source bug ship)
- **File**: `Tests/SudokuCoreTests/Board/BoardValidationTests.swift`
- **Failure mode**: the suite tests `completedRows/Cols/Houses/Numbers` and `isSolved`, but never that `incorrectMoves == 1` after one wrong placement, or `== 1` after a wrong placement followed by several correct placements (where the source bug would inflate it).
- **Suggested fix**: add a test that places a wrong digit (vs. provided solution), then makes 5 correct moves, and asserts `board.incorrectMoves == 1`. Will currently fail given the Source bug — fix that first.

#### [Low] No test covers `eliminatePencilMarks` vs `updatePencilMarks` distinction
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Board/BoardValidationTests.swift`
- **Failure mode**: the two methods do subtly different things; only the latter is tested.
- **Suggested fix**: add a test that pre-populates pencil marks, calls `eliminatePencilMarks`, and asserts only invalid candidates were removed.

### SudokuSolverTests.swift

#### [Low] `invalidPuzzle` constant defined but never used
- **Category**: dead test fixture
- **File**: `Tests/SudokuCoreTests/SudokuSolverTests.swift:53-62`
- **Failure mode**: the 8×8 (rather than 9×9) `invalidPuzzle` is declared but never referenced in any test. It looks like it was meant to test the solver with malformed input but the test was never written.
- **Suggested fix**: either add the test (`SudokuSolver.solve` should return nil for malformed grids) or delete the constant.

#### [Low] No test covers solver with empty grid (should produce *some* solution if it returns one)
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/SudokuSolverTests.swift`
- **Failure mode**: `Solution.empty()` has 6.7×10²¹ valid solutions. The solver may take a very long time. Worth verifying behavior — add a test with a `Task.timeout` or explicit cap.

### Generation/SudokuGeneratorTests.swift

#### [Low] Only 2 tests cover the entire generator
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Generation/SudokuGeneratorTests.swift`
- **Failure mode**: tests cover batched-removal correctness with custom `cellsOrder` and `uniqueCheck`. They don't cover:
  - Default-args generation produces a valid puzzle (round-trip via solver).
  - Difficulty distribution across many runs (not statistical, just sanity).
  - `generatePuzzle(targetsEmptyCells:)` respects the range.
  - Failure modes: what if `solution` is invalid? What if `targetEmpty > 81`?
- **Suggested fix**: add at least an integration-style "generate 100 puzzles, all are uniquely solvable, all have `targetEmpty` empty cells" test.

### HintTests.swift

#### [Low] `testHintsAreDeterministic` only checks `actions.count` and `technique`, not actual actions
- **Category**: weak assertion
- **File**: `Tests/SudokuCoreTests/HintTests.swift:416-440`
- **Code**:
  ```swift
  #expect(h1.technique == h2.technique)
  #expect(h1.actions.count == h2.actions.count)
  // Note: Don't compare exact actions as Set order may differ
  ```
- **Failure mode**: actions could be entirely different cells producing the same count and technique label, and the test would pass. The "Set order" comment dodges the real issue: actions should be comparable as a set, not as an array. If they aren't comparable as a set, that's a Source-side issue (HintAction Hashable is implemented, so sets work).
- **Suggested fix**: compare `Set(h1.actions) == Set(h2.actions)` (HintAction conforms to Hashable per HintAction+Helpers.swift).

#### [Low] `testHintsAlwaysReduceCandidates` fails silently for techniques with no impact
- **Category**: brittle assertion
- **File**: `Tests/SudokuCoreTests/HintTests.swift:390-414`
- **Failure mode**: a hint that only places a value (e.g. naked single) reduces candidates by emptying that cell's pencil marks. But what if there were ZERO pencil marks for the cell to begin with (which shouldn't happen, but defensive programming)? Then `newCount < originalCount` could fail because the count was already 0. The test relies on a property that's almost always true in practice but isn't strictly required by the technique definitions.
- **Suggested fix**: assert `newCount <= originalCount` and additionally assert at least one of the hint's actions actually applied (i.e. a `solveAs` filled a cell or a `ruleOut` removed a candidate that existed).

#### [Low] `testFindAllHints` permits "extra techniques" to fire — useful test info is silently swallowed
- **Category**: weak assertion
- **File**: `Tests/SudokuCoreTests/HintTests.swift:617-656`
- **Failure mode**: the test computes `extraTechniques = foundTechniques.subtracting(testCase.expectedTechniques)` but only logs it as a comment ("This helps us understand what other hints are available"). If a refactor produces unexpected hint detections (false positives in a technique), the test won't fail. Worse, the comment block at lines 652-655 has no actual logging code — it's just a comment.
- **Suggested fix**: either fail on extra techniques (strict), or log them via `Issue.record(...)` with `severity: .information` so they appear in test output without failing the run.

#### [Low] `testGrids` uses hard-coded grid strings without a way to regenerate them
- **Category**: maintainability
- **File**: `Tests/SudokuCoreTests/HintTests.swift:16-319`
- **Failure mode**: ~130 grid strings, mixed plain-81-char and `SCv7_32_` encoded sudoku.coach format. There's no provenance info — where did each come from? If a technique's expected fixture stops being detectable due to a Source change, you can't regenerate or replace it without going back to the original source.
- **Suggested fix**: add a comment block above each technique's array citing the source (puzzle-author site, manual construction, etc.) and the rationale (e.g. "this grid has exactly one X-Wing and no easier technique applies"). For `SCv7_32_` strings, decode them once at audit time and store the plain-81 form as a comment.

### HintExplanationTests.swift

#### [Low] `expectedStepCounts` uses exact min==max for most techniques — brittle
- **Category**: brittleness
- **File**: `Tests/SudokuCoreTests/HintExplanationTests.swift:14-38`
- **Failure mode**: e.g. `(.nakedPair, min: 3, max: 3)` — exactly 3 steps required. If a refactor adds a 4th explanatory step (a UX improvement), the test fails. The min/max range is the right idea but everywhere it collapses to a single value.
- **Suggested fix**: widen to a reasonable range (e.g. min: 2, max: 5) or replace with "at least" assertions where the floor is the contract and the ceiling is informational.

### HardPuzzleDifficultyTests.swift

#### [Low] `SeededGenerator` is defined but never used in this file
- **Category**: dead code
- **File**: `Tests/SudokuCoreTests/HardPuzzleDifficultyTests.swift:19-36`
- **Failure mode**: a Xoroshiro128** RNG is implemented but unused in the test suite (`grep` confirms). It's likely a leftover from an earlier randomized-test approach.
- **Suggested fix**: delete or move it to a shared test utility if needed elsewhere.

#### [Low] Test asserts `result.score >= 600` for "hard or expert" but the score is `Double` (raw HoDoKu)
- **Category**: type confusion
- **File**: `Tests/SudokuCoreTests/HardPuzzleDifficultyTests.swift:67-68`
- **Failure mode**: `result.score` is a Double — see the Source finding about misleading "0-1 normalised" doc. Tests treating it as an Int-like rating reinforce the API confusion rather than catching it.
- **Suggested fix**: align Source and tests (either `score: Int` or document the Double semantics clearly), then update tests to use the corrected type.

### RatedPuzzles.swift

#### [Low] HoDoKu rating tolerances of ±150 (vs default ±20) effectively allow any rating in a class
- **Category**: weak assertion
- **File**: `Tests/SudokuCoreTests/RatedPuzzles.swift:74, 86, 98`
- **Failure mode**: "very easy" expected 510 ± 150, "easy" expected 490 ± 150. The bands overlap — a single computed rating of 500 would match both. Tests pass even if the rating system drifts substantially.
- **Suggested fix**: tighten tolerances OR add separate "loose" and "strict" classes of rated puzzles, with the strict ones using the default ±20.

#### [Low] Rated puzzles' `expectedHoDoKu` includes the `0.05 × eliminations` modifier (per the comments)
- **Category**: rating semantics
- **File**: `Tests/SudokuCoreTests/RatedPuzzles.swift:67, 78, 90`
- **Failure mode**: the comments say "Actual: HoDoKu ~510 (with modifiers)". So the expected values are calibrated to the non-canonical modifier — if you fix the Source finding (drop the modifier), every test in this file needs new expected values. Tests are coupled to the Source's deviation from canonical HoDoKu.
- **Suggested fix**: when fixing the Source modifier, run a re-calibration pass and update these expected values.

### Rating/HoDoKuCalculatorTests.swift

#### [Low] `testRatingCorrelation` is named "correlation" but only checks `> 0` — doesn't actually test correlation
- **Category**: misleading test
- **File**: `Tests/SudokuCoreTests/Rating/HoDoKuCalculatorTests.swift:85-102`
- **Failure mode**: the test name implies "easier puzzles get lower ratings than harder puzzles." The body just asserts each rating is `> 0` and that one specific puzzle is within tolerance. No comparison between difficulty tiers.
- **Suggested fix**: add `#expect(veryEasyResult.rating < mediumResult.rating)` and `mediumResult.rating < hardResult.rating` (or relax with a tolerance for technique-count fluctuations).

#### [Low] `testBreakdownAccuracy` allows ±10% tolerance — could mask rounding bugs
- **Category**: weak assertion
- **File**: `Tests/SudokuCoreTests/Rating/HoDoKuCalculatorTests.swift:122-135`
- **Failure mode**: the breakdown is supposed to sum exactly to the rating (or with a known modifier offset). 10% tolerance permits arbitrary drift.
- **Suggested fix**: tighten to a small absolute tolerance (e.g., ±1 point) once the modifier semantics are fixed.

### Rating/PersonalizedCalibratorTests.swift

#### [Low] No test covers the `mad` (Median Absolute Deviation) function with `< 3` samples
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Rating/PersonalizedCalibratorTests.swift`
- **Failure mode**: `mad` returns 0 with fewer than 3 samples — see Source finding. No test asserts the resulting `predict.rangeUpper/Lower` falls back to ±12.5%.

### Rating/TimeEstimatorTests.swift

#### [Low] Only one test (18 lines total) for the entire `TimeEstimator` namespace
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Rating/TimeEstimatorTests.swift`
- **Failure mode**: tests that baseline grows with rating and personalisation produces non-nil. Doesn't test:
  - `userSpeedFactor` clamping at the boundary (0.4 and 2.5).
  - Behaviour at HoDoKu rating 0 or negative (currently `max(1, rating)` handles it).
  - Range bounds (`rangeLower < seconds < rangeUpper`).
  - Disagreement vs `PersonalizedCalibrator.baselineSeconds(for:)`.
- **Suggested fix**: expand to ~5-6 tests covering edge cases.

### Rating/SolvePathEmitterTests.swift

#### [Low] Only 2 tests for the path emitter
- **Category**: coverage gap
- **File**: `Tests/SudokuCoreTests/Rating/SolvePathEmitterTests.swift`
- **Failure mode**: tests emit + determinism on a near-solved board. Doesn't cover:
  - Multi-step solve path (e.g. requires hidden singles + naked pairs).
  - Iteration cap behaviour (`maxIterations` exceeded).
  - Empty grid (which `firstHint` should return nil on quickly, producing 0-step path).
  - Returns from the middle of a chain when a technique we don't support is needed.

### BoardStateParserTests.swift

#### [Low] Test comment claims `(0,6)` but assertion checks `[1][6]`
- **Category**: doc/code mismatch
- **File**: `Tests/SudokuCoreTests/BoardStateParserTests.swift:97-100`
- **Code**:
  ```swift
  // Verify known pencil marks
  #expect(
      state.validOptions[1][6] == Set([2, 3]),
      "Cell (0,6) should have pencil marks {2, 3}"
  )
  ```
- **Failure mode**: the assertion message says "(0,6)" but the array index is `[1][6]` (row 1, column 6). The expected set is presumably correct; the message is wrong. If this test ever fails, debugging would point at the wrong cell.
- **Suggested fix**: change message to "Cell (1,6)..."

#### [Low] Test puzzle strings are 100+ characters and uncommented
- **Category**: maintainability
- **File**: `Tests/SudokuCoreTests/BoardStateParserTests.swift` (multiple)
- **Failure mode**: same as the HintTests.testGrids finding — provenance is unclear. The `SCv7_32_` strings are opaque. Decoding them once at audit time as plain comments would help future maintainers.

### General test-suite findings

#### [Low] No tests run with deterministic RNG seed (Swift Testing parallelism + random fixtures)
- **Category**: flakiness risk
- **File**: across the suite
- **Failure mode**: Swift Testing runs tests in parallel by default, and many tests use `Solution.randomNotValid()`, `(1...9).shuffled()`, or rely on `Set` iteration order. No `@Suite(.serialized)` or similar. If any test mutates shared state via `static var`, results may flake under concurrency.
- **Suggested fix**: audit for static-mutable state and add `.serialized` to suites that need it. For random-fixture tests, plumb a seeded RNG through the API surface (or document the flakiness budget).

#### [Low] Heavy reliance on `try!` and `!` in test setup
- **Category**: brittleness
- **File**: across the suite
- **Failure mode**: a `try!` or force-unwrap in test setup fails the whole test with no useful diagnostic. Use `#expect(throws: ...)` or `try` with a `do/catch` wrapping `Issue.record`.
- **Suggested fix**: prefer `try` or `try?` with explicit guard + `Issue.record`.

#### [Low] Test fixtures for hint techniques mix plain 81-char strings and `SCv7_32_` encoded strings within the same array
- **Category**: maintainability
- **File**: `Tests/SudokuCoreTests/HintTests.swift:16-319`
- **Failure mode**: scanning the test grids, you can't tell at a glance which fixtures use grid-only state and which include pencil-mark state. Some techniques (hidden subsets, fish patterns) may need explicit pencil marks to fire — using plain 81-char strings effectively asks the parser to compute candidates with `Validator.validOptions`, which may not match the intended state.
- **Suggested fix**: prefer one consistent format. Document which one and why.

---

## Round 2: Verification + Additional Findings (2026-06-02)

A re-audit was performed on 2026-06-02. No code changes shipped between Round 1 and Round 2 (last commit `0c85335` 2026-02-25).

### Verification Status Summary

**134 of 135 Round 1 findings re-verified against current source. Default for the fixer: every Round 1 finding is Verified unless it appears in the "Disputed" or "Severity Disagreements" list below.**

### Disputed Findings (1)

#### `[Low] Validation seen[value] = currentIndex overwrites the original conflict cell on triple+ duplicates`
- **Location in Round 1**: `Hints/Hint Implementation/Validation.swift` section
- **Round 2 Status**: **Disputed**
- **Reasoning**: Trace of X at cols 1, 4, 7 in one row:
  - col 1: `seen[X]` is nil; no conflict branch; `seen[X] = col1`.
  - col 4: `seen[X] = col1`; conflict branch inserts col 4 AND col 1 into `conflictCells`; `seen[X] = col4`.
  - col 7: `seen[X] = col4`; conflict branch inserts col 7 AND col 4 into `conflictCells`; `seen[X] = col7`.

  Final `conflictCells = {col1, col4, col7}` — all three appear. The Round 1 author's mid-sentence "wait actually" indicates they realised the trace mid-write. The claim that "column 1 is no longer reported" is incorrect.
- **However**: there IS a real bug in the same code, just not the one Round 1 described. Only col 4 and col 7 get clear *actions* (the first occurrence is treated as the "kept" placement and gets no action), but all three appear in `conflictCells`. The actions-vs-cells asymmetry is real — see new finding **[R2-002]**.
- **Action for fixer**: Skip the Round 1 finding. Implement [R2-002] instead.

### Severity Disagreements (7)

Round 2 traced through actual call sites and proposes severity adjustments. **Original severity is preserved in the body**; Round 2's view is documented here so the fixer can decide.

| Round 1 Finding | Original | Round 2 suggests | Reason |
|---|---|---|---|
| `[Medium] BoardState initialiser allows ill-formed grids silently` (`Hints/BoardState.swift`) | Medium | Low | Only one caller (`HintViewModel.init()`) uses the empty default; that caller immediately replaces the value via the next user assignment. No code path today reads `grid[r][c]` on a zero-init. Hardening opportunity, not active bug. |
| `[Medium] BoardState.applying ignores .pencilIn actions entirely` (`Hints/SolveUtilities.swift`) | Medium | Low | Grep across all hint files: no current technique emits `.pencilIn` HintAction. The infinite-loop hazard described isn't reachable today. Latent API hazard. |
| `[Medium] Hint search runs all 21 techniques in parallel then sorts` (`Hints/HintViewModel.swift`) | Medium | Low | Coupled to the all-hints design: `hint(for:)` public accessor evidences the API intentionally maintains one-hint-per-technique. (Note: it's 24 cases, not 21.) Recommend collapsing this and the next into one Low docs/API-clarity finding. |
| `[Medium] availableHints exposes ALL technique hints for current state` (`Hints/HintViewModel.swift`) | Medium | Low | Same root: by-design per `hint(for:)` accessor. Reframe as documentation / API-clarity. |
| `[Medium] Finned fish accepts up to n+2 cross lines` (`Hints/Hint Implementation/FishPatterns.swift`) | Medium | Low | `validateFins` enforces (a) all fins share one 3×3 box, AND (b) eliminable cell sees every fin. Per HoDoKu's own canonical definition, this is exactly the right safety net for any fin count. Effect on eliminations: none. Only difficulty granularity is coarser. |
| `[Low] RatingTables.TimeMapping.logModel = (2.0, 2.2) is uncited` (`Rating/RatingTables.swift`) | Low | Medium | At rating 100: log-model says 12 min, `PersonalizedCalibrator` anchors say 3 min. Substantial inter-estimator disagreement is a silent breakage risk for any downstream code that reads from either. |
| `[Low] classRangesMinutes uses string keys that drift from PuzzleDifficulty.Level enum cases` (`Rating/RatingTables.swift`) | Low | Medium | Keys are `"Basic"/"Easy"/"Moderate"/"Hard"/"Very Hard"/"Extreme"`. `PuzzleDifficulty.Level.debugDescription` returns `"Beginner"/"Intermediate"/"Advanced"/"Expert"/"Master"/"Custom"`. Zero overlap — any lookup against `debugDescription` silently misses every time. |

### Round 2 Additional Findings (14)

The Round 1 audit had ~1 finding per technique for 18+ hint techniques. Round 2 did a deep correctness pass against canonical Sudoku rules and surfaced 14 new findings: **1 High, 9 Medium, 4 Low**. IDs `[R2-001]`…`[R2-014]` for easy cross-reference.

#### [R2-001] [High] `BoardState.applying` does not refresh pencil marks for `.clear` actions
- **Category**: correctness
- **File**: `Sources/SudokuCore/Hints/SolveUtilities.swift:45-46`
- **Code**:
  ```swift
  case .clear:
      newGrid[action.position.row][action.position.column] = 0
  ```
- **Failure mode**: When a hint action clears a cell (e.g. from a Validation hint reverting a misplaced digit), `newGrid` is updated but `newPencilMarks` for that cell is left untouched. Most likely the cell had `[]` as its pencil marks (set when a previous `.solveAs` placed the value at line 40). The final merge at lines 50-56 recomputes `validOptions` from the new grid but then intersects with the stale `[]` pencil marks — intersection with `[]` is still `[]`. The just-cleared cell ends up with zero pencil marks even though it has many valid options. Subsequent hint searches treat the cell as having no candidates; techniques like NakedSingle, HiddenSingle, NakedSubsets, etc. silently cannot fire there. `SolvePathEmitter` is the primary consumer — it would stall past a cleared cell and bail at `maxIterations`. `SudokuDifficultyCalculator` then falls back to the AC solver and mis-rates the puzzle.
- **Reproduction**: Build a `BoardState` representing a partial board where the user has placed a wrong digit. Construct a Validation hint with a `.clear` action. Call `state.applying(hint)`. Then `state2.pencilMarks[row][col]` for the cleared cell will be `[]` instead of the cell's valid options. Subsequent `HintFinder.firstHint(in: state2)` will not return a hint targeting that cell, even when it's a naked single in the new state.
- **Suggested fix**: For `.clear`, treat the cell as needing a fresh candidate set. Either (a) explicitly set `newPencilMarks[r][c]` to the recomputed `validOptions[r][c]` in the `.clear` branch, or (b) change the merge logic at the bottom: for any cell where `newGrid[r][c] == 0 && newPencilMarks[r][c].isEmpty`, use `validOptions[r][c]` directly without intersection. (b) is cleaner and also handles the `.solveAs`-then-undo edge case.
- **Test coverage gap**: `SolvePathEmitterTests` should include a puzzle where the path starts with a misplaced digit cleared by a Validation hint, then asserts that the next hint correctly fires on the now-empty cell.

#### [R2-002] [Medium] `Validation` returns a `HintStep` whose `actions` set is smaller than its `conflictCells` (triple-conflict asymmetry)
- **Category**: correctness / UX
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/Validation.swift:31-49` (and parallel structures at 64-82, 97-118)
- **Code**:
  ```swift
  for col in 0..<9 {
      let value = state.grid[row][col]
      if value != 0 {
          if let previousIndex = seen[value] {
              ...
              conflictActions.append(HintAction(clearPosition: currentIndex))
              conflictCells.insert(currentIndex)
              conflictCells.insert(previousIndex)
          }
          seen[value] = Puzzle.Index(row: row, column: col)
      }
  }
  ```
- **Failure mode**: When a single row/column/box has *three or more* duplicates of the same digit (e.g. cells (0,0), (0,2), (0,4) all hold value `1`), only the **second and third** occurrences are added to `conflictActions` (the first cell is treated as the "kept" placement and gets no clear action), but all three appear in `conflictCells`. The result is `conflictCells = {(0,0), (0,2), (0,4)}` highlighted in the explanation but `conflictActions = [clear(0,2), clear(0,4)]` — the highlighted-vs-cleared sets disagree. The Round 1 audit caught the `seen[value]` overwrite issue but mis-traced what it meant (see Round 2 Disputed above); this finding is the real bug.
- **Reproduction**: Construct a board where the user has placed `1` in three cells of the same row. Call `HintFinder.findHint(for: .validation, in: state)`. Assert `Set(hint.actions.map(\.position)) == conflictCells` from the explanation. This will fail.
- **Suggested fix**: On the second occurrence, also append a `clearPosition` action for the first occurrence (i.e. `conflictActions.append(HintAction(clearPosition: previousIndex))`). Use a `firstSeen[value]: Puzzle.Index` map that is never overwritten, plus a `clearedFirst: Set<Int>` flag set to avoid double-adding the first occurrence on third+ duplicates.
- **Test coverage gap**: `HintValidationTests` should include a triple-duplicate row case asserting that all three positions appear in `actions`.

#### [R2-003] [Medium] Every hint technique trusts user-narrowed pencil marks — `ruleOut` of a true candidate produces wrong hints
- **Category**: correctness (architecture)
- **File**: `Sources/SudokuCore/Hints/Board+State.swift:24`; affects every technique
- **Code**:
  ```swift
  // Board+State.swift
  pencilMarks[row][col] = cell.validOptions
      .subtracting(cell.ruledOutCandidates)
  ```
- **Failure mode**: The hint pipeline reads `state.pencilMarks`, which `Board.state` computes as `validOptions - ruledOutCandidates`. If the user accidentally rules out a candidate that IS a valid placement, the pencil marks shrink to a wrong-but-internally-consistent set, and the engine derives "valid" hints from it. Concrete case: cell C has true valid options `{3, 7}`. User `ruleOut`s `3` (mistake). Now `pencilMarks[C] = {7}` and `findNakedSingle` returns `solveAs: 7` for C — even when the puzzle's solution puts `3` in C. Applying the hint enters the wrong digit; the next pass fires a Validation hint chasing the user's own bad input. Every other technique (HiddenSingle, NakedSubsets, HiddenSubsets, Locked Candidates, Fish, Wings, Skyscraper, Two-String Kite, Empty Rectangle, W-Wing, XY/Y/XYZ-Wing) shares this same trust assumption.
- **Reproduction**: Build a Board with a known puzzle. Use `ruleOut` to remove a candidate that is the correct answer for some cell. Call `HintFinder.firstHint(in: board.state)` and assert it returns a hint that places the wrong digit. This will pass (i.e. confirm the bug).
- **Suggested fix** (design decision required): three options:
  - (a) Hint engine ignores `ruledOutCandidates` entirely — use `validOptions` everywhere. Loses the "user explored possibilities" optimisation but is safe.
  - (b) Hint engine validates that ruled-out candidates are not in fact the solution before trusting them. Requires `state.solution` always being available; not all callers can provide this.
  - (c) Document the trust assumption loudly and add a pre-check ("your pencil marks look wrong" warning if any unplaced cell has 0 candidates).
  Either (a) or (c) is recommended; (b) breaks for puzzles created from raw grids without a known solution.
- **Test coverage gap**: A test that intentionally rules out a true candidate and asserts the hint engine either ignores the ruleOut or refuses to produce a hint placing a wrong digit.

#### [R2-004] [Medium] `findHiddenSingle` silently ignores digits with zero candidate cells in a unit (missed contradiction)
- **Category**: robustness / correctness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSingles.swift:55-72`
- **Code**:
  ```swift
  for digit in 1...9 {
      let positions = digitPositions[digit]
      if positions.count == 1 {
          ...
      }
  }
  ```
- **Failure mode**: The code only acts on `positions.count == 1`. But `positions.count == 0` for an unplaced digit means digit `D` has no candidate cells anywhere in the unit — an unsolvable contradiction. The function silently moves on. `SolvePathEmitter` will eventually stall, fall back to AC, and surface "puzzle is unsolvable" much later. Catching the contradiction at hint-find time would let `HintFinder` return a `validation`-style hint immediately with a precise explanation ("digit X has no place in row Y").
- **Reproduction**: Build a board where the player's pencil marks (real or user-ruled-out) eliminate digit 5 from every cell of row 0, and row 0 doesn't contain a 5. `findHiddenSingle` returns nil. `findNakedSingle` also returns nil. Solver stalls.
- **Suggested fix**: When `digitToCells[digit].isEmpty` for an unplaced digit, return a contradiction hint (`technique: .validation`), or surface a `BoardState.isUnsolvable` flag. At minimum, document that this silent skip is intentional.
- **Test coverage gap**: Add a test that constructs a contradictory state (digit ruled out everywhere in one row) and asserts the engine reports it instead of returning nil.

#### [R2-005] [Medium] `HiddenSubsets` can mis-classify a hidden single as hidden pair/triple/quad
- **Category**: correctness (misclassification)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/HiddenSubsets.swift:88-138`
- **Failure mode**: For a hidden pair on digits `{A, B}`, the code requires `unionCells.count == n` (= 2). If digit `A` is only in cell `(r, c1)` and digit `B` is in cells `(r, c1)` and `(r, c2)`, the union is `{(r, c1), (r, c2)}` — count 2 — and the test fires. But digit `A` is a hidden single (only 1 cell). The hint engine reports this as `.hiddenPair` (difficulty 50), when it should have been caught as `.hiddenSingle` (difficulty 20). Via `firstHint`, hidden singles run first and prevent this; BUT direct calls via `HintFinder.findHint(for: .hiddenPair, ...)` (used by `HintViewModel`'s parallel search) return the misclassified hint. Eliminations are valid; technique label, difficulty rating, and "these two digits can only appear in these two cells" explanation are all misleading.
- **Reproduction**: Construct a grid where a digit is a hidden single and another digit has exactly 2 candidates including the hidden single's cell. Call `HintFinder.findHint(for: .hiddenPair, in: state)` and assert the returned hint's `technique == .hiddenPair`. It will, but the puzzle reading should be "hidden single."
- **Suggested fix**: Reject combos where any digit in `digitCombo` has `digitToCells[digit].count < 2`. (For a hidden pair, every digit in the pair must appear in at least 2 cells, else it's a hidden single.)
- **Test coverage gap**: A direct-API test (not via `firstHint`) that builds a state with a hidden single and asserts `findHint(for: .hiddenPair, in: state)` returns nil.

#### [R2-006] [Medium] `LockedCandidatesPointing` can fire on a hidden single in a box and mislabel it
- **Category**: correctness (misclassification)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/LockedPointing.swift:52, 92`
- **Code**:
  ```swift
  if possibleRows.count == 1, let lockedRow = possibleRows.first, possiblePositions.count > 0 {
  ```
- **Failure mode**: The guard `possiblePositions.count > 0` admits even a single candidate cell. If digit `D` has exactly 1 candidate in a box, it's a hidden single — but the code treats it as a pointing pattern (the digit is "confined to one row" because that one cell is in one row). Eliminations from the rest of that row are still valid (the hidden single's placement implies them anyway), but the technique is mislabelled. Via `firstHint`, hidden singles run first; direct `findHint(for: .lockedCandidatesPointing, …)` from `HintViewModel`'s parallel search returns the misclassified hint with difficulty 40 instead of 20.
- **Reproduction**: Construct a grid where digit 5 has exactly 1 candidate cell in box 0 at (0, 0), and row 0 outside box 0 has 5 as a candidate elsewhere. Call `findHint(for: .lockedCandidatesPointing, in: state)`; assert `technique == .lockedCandidatesPointing`. It will.
- **Suggested fix**: Require `possiblePositions.count >= 2` (a true pointing/claiming requires at least two candidate cells in the box confined to one line). Apply the same fix to `LockedClaiming` if symmetric.
- **Test coverage gap**: A direct-API test with the above construction asserting nil.

#### [R2-007] [Medium] `XY-Wing` and `Y-Wing` are byte-identical predicates — `HintViewModel`'s parallel search emits duplicate hints
- **Category**: correctness (duplication, UX)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:239-261, 274-296`
- **Failure mode**: Round 1 noted the code duplication. The deeper consequence: when `HintViewModel.lookForHints` schedules both `.xyWing` and `.yWing` searches concurrently, **both produce hits on every XY-Wing pattern** because they apply the same predicate. `availableHints` then surfaces the same hint twice (once labelled "XY-Wing", once "Y-Wing"). Difficulty 110 for both means `currentHint` picks non-deterministically. The user sees two redundant hints in any "show all hints" UI.
- **Reproduction**: Build a state with one XY-Wing. Call `findHint(for: .xyWing, in: state)` and `findHint(for: .yWing, in: state)`. Assert both return a hint with the same actions but different `technique` field.
- **Suggested fix**: Pick one to be canonical. Either (a) make Y-Wing genuinely "relaxed" per the doc comment (e.g. allow tri-value pivot — but that's actually XYZ-Wing), or (b) merge the two and pick one label, or (c) make `findHint(for: .yWing, ...)` return nil and route all callers to `.xyWing`. Design decision required.
- **Test coverage gap**: A test asserting that for a board with one XY-Wing, only one of `findHint(for: .xyWing)` / `findHint(for: .yWing)` returns non-nil.

#### [R2-008] [Medium] `EmptyRectangle` candidate iteration is non-deterministic due to `Set<Int>` iteration order
- **Category**: correctness (determinism)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/EmptyRectangle.swift:53-54`
- **Code**:
  ```swift
  for erRow in candidateRows {
      for erCol in candidateCols {
  ```
- **Failure mode**: `candidateRows` and `candidateCols` are `Set<Int>` constructed from `candidatePositions.map(\.row)` and `.column`. Swift `Set` iteration order is hash-seed dependent and not stable across processes. On a board with multiple valid `(erRow, erCol)` combinations producing different eliminations, the first-returned hit may vary between runs. Tests depending on a specific elimination set may flake. Round 1 noted this as Low; bumping to Medium because deterministic test fixtures across CI runs are a real reliability concern.
- **Reproduction**: An ER box with 4 candidate cells forming two valid `(erRow, erCol)` pairs that yield different eliminations. Run `findEmptyRectangle` repeatedly across multiple Swift processes; the returned hint's `actions` may differ.
- **Suggested fix**: `for erRow in candidateRows.sorted() { for erCol in candidateCols.sorted() { ... } }`. Cheap; deterministic.
- **Test coverage gap**: A determinism test that repeats the call (across simulated process boundaries) and asserts consistent output.

#### [R2-009] [Medium] `findWWing` permits `cellA` and `cellB` to see each other, reporting a hint that is actually a Naked Pair
- **Category**: correctness (misclassification)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WWing.swift:97-122` (in `tryWWingConnection`)
- **Failure mode**: A canonical W-Wing requires the two bi-value cells to NOT see each other; otherwise they form a Naked Pair, which is a stronger and easier deduction. The current code does not enforce this. When `cellA` and `cellB` share a row/column/box, the hint engine reports a W-Wing (difficulty 95) when a Naked Pair (difficulty 50) would suffice. Eliminations are correct but the technique misclassification inflates the puzzle's difficulty rating. Via `firstHint`, Naked Pair runs first; via `HintViewModel` parallel search, both fire and the user sees redundant hints.
- **Reproduction**: Build a state with two cells in row 0 both containing `{1, 5}` plus a strong link on 5 elsewhere. Call `findHint(for: .nakedPair, in: state)` (returns hint). Call `findHint(for: .wWing, in: state)` (also returns hint).
- **Suggested fix**: Add `guard !LookupTables.cellNeighbours[cellA.row][cellA.column].contains(cellB) else { continue }` at the start of `tryWWingConnection`.
- **Test coverage gap**: A test asserting that a board with a naked pair does NOT also produce a W-Wing hint on the same cells.

#### [R2-010] [Medium] Fish patterns silently accept partially-degenerate base lines (`baseLinesWithPositions.count < n`)
- **Category**: correctness (misclassification)
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/FishPatterns.swift:379-382`
- **Code**:
  ```swift
  let baseLinesWithPositions = Set(fishPositions.map { getBase($0) })
  if baseLinesWithPositions.count < 2 {
      continue
  }
  ```
- **Failure mode**: The check is `< 2` regardless of `n`. For `n = 3` (Swordfish), only 2 base lines actually having positions in core cross lines means it's actually an X-Wing pattern. With perfect fish this is impossible (each base line has its candidates in core when `allCrossLines.count == n`). With finned fish (`allCrossLines.count > n`), a base line's candidates could all be in fin cross lines (zero core positions). HoDoKu canonical Sashimi-fish allows AT MOST one base line with only-fin positions; the current code permits arbitrary numbers of fin-only base lines, mis-classifying smaller patterns as larger fish.
- **Reproduction**: Construct a Swordfish-shaped pattern where one of the three base lines has its only candidates in a fin cross line. Call `findHint(for: .finnedSwordfish, in: state)`; assert it does NOT return a hint. If it does, the over-strict acceptance has fired.
- **Suggested fix**: Change `< 2` to `< n - 1` (Sashimi allows one base line with no core positions). Stricter alternative: `< n` (reject all Sashimi).
- **Test coverage gap**: A test with a partial-base-line finned fish; assert technique classification matches the strict definition.

#### [R2-011] [Low] `NakedSubsets` materialises `combinations(...)` on every unit
- **Category**: performance
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/NakedSubsets.swift:77`
- **Failure mode**: For each unit (27 total) and each `n`, `combinations(of:choose:)` is re-allocated. For n=4 with 8 candidate cells, that's `C(8,4) = 70` combinations per unit. Bounded but per-call allocation is real, especially called per hint-refresh.
- **Suggested fix**: Use the lazy iterator from `swift-algorithms` directly rather than collecting via `Array(...)`. Same applies to `HiddenSubsets.swift` if symmetric.
- **Test coverage gap**: Benchmark only.

#### [R2-012] [Low] `validateXYZWing` accepts "extended" XYZ-Wings (definition deviation, not a bug)
- **Category**: documentation / definition fidelity
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:309-323`
- **Failure mode**: Canonical XYZ-Wing: pivot = `{X, Y, Z}`, wingA = `{X, Z}`, wingB = `{Y, Z}`. Current implementation accepts any pair of bi-value subsets of the tri-value pivot with intersection size 1. For example, pivot = `{1, 2, 3}`, wingA = `{1, 2}`, wingB = `{2, 3}`, intersection = `{2}` — same deduction holds (the eliminable digit is the intersection, present in all three of pivot/wingA/wingB in every case-by-case analysis). So **the logic is sound** but the predicate is broader than the textbook XYZ-Wing form.
- **Suggested fix**: Document the deviation in the doc comment. Optionally tighten to canonical form by requiring `pivot.subtracting(wingA).count == 1` and `pivot.subtracting(wingB).count == 1`.
- **Test coverage gap**: A test with the extended form asserting whether the engine treats it as XYZ-Wing per the project's chosen definition.

#### [R2-013] [Low] `findEliminationCells` for XY/Y-Wing relies on pivot being implicitly excluded by candidate filter
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/WingPatterns.swift:362-380` (`findEliminationCells`)
- **Failure mode**: For XY/Y-Wing, `potentialCells = wingANeighbours.intersection(wingBNeighbours)` — this includes the pivot (pivot is a peer of both wings). The pivot is not an elimination target, but it's not explicitly excluded. The downstream filter `pencilMarks[…].contains(digit)` saves the day today: pivot's pencilMarks are `{X, Y}` and the elimination digit is `Z`, not in pivot. But if a future refactor permits pivots with Z in their candidates (e.g., "Almost XY-Wing" research), the elimination set would incorrectly include the pivot.
- **Suggested fix**: Explicitly exclude pivot, wingA, wingB:
  ```swift
  potentialCells = wingANeighbours.intersection(wingBNeighbours)
      .subtracting([pivot.pos, wingA.pos, wingB.pos])
  ```
  Cheap; defensive.
- **Test coverage gap**: A future test for "Almost XY-Wing" if introduced would catch a regression.

#### [R2-014] [Low] `Validation` silently ignores malformed `solution` arrays of incorrect dimensions
- **Category**: robustness
- **File**: `Sources/SudokuCore/Hints/Hint Implementation/Validation.swift:134-137`
- **Code**:
  ```swift
  if let solution = state.solution,
      solution.count == 9,
      solution.allSatisfy({ $0.count == 9 })
  ```
- **Failure mode**: A solution of length 8 or 10 (or rows of irregular length) is silently treated as "no solution available." The caller has no way to detect the malformed input — they get back "no error" but also no wrong-cell detection. If a callsite expects solution-based checking to work, they get a false-clean result.
- **Suggested fix**: Add a precondition at the `BoardState` init layer (Round 1 already flagged this elsewhere as `[Medium] BoardState initialiser allows ill-formed grids silently`), OR surface a `.unknown` technique hint with explanatory text when the solution is malformed.
- **Test coverage gap**: A test feeding a malformed solution and asserting either an error or graceful surfacing.

### Techniques That Verified Clean (No new findings)

Round 2 traced each technique's deduction logic against canonical Sudoku rules. The following techniques' **deduction math is sound** — they correctly identify their pattern and emit valid eliminations. Findings under their files from Round 1 (style, perf, force-unwraps) still stand, but no new correctness bugs were discovered in the deduction itself:

- **NakedSingles** — Iterates `state.pencilMarks`; if `count == 1`, places the digit. Correct under the trust assumption flagged in [R2-003].
- **LockedCandidatesClaiming** — Correctly identifies digit confined to one box within a row/column. (The mis-classification concern in LockedPointing [R2-006] does not arise here because Claiming starts from row/column and finds confinement to a box, not the other way.)
- **X-Wing, Swordfish, Jellyfish** (perfect, non-finned) — Standard fish; elimination set is correct.
- **Finned X-Wing, Finned Swordfish, Finned Jellyfish** — Fin-detection and validation (same-box constraint, "elimination cell must see all fins") are correct. The Round 1 `n+2` cross-lines acceptance was downgraded to Low in Severity Disagreements above.
- **Skyscraper** — Row-base/column-base symmetry, common-cross-line constraint, elimination set: all sound.
- **Two-String Kite** — Strong link selection, box-sharing endpoint pairing, kite-tip elimination logic: all sound.
- **Empty Rectangle** — Box-confinement check, strong-link-outside-box requirement, target-not-in-box check: sound. (Determinism concern raised in [R2-008].)
- **W-Wing** — Strong link split between wings, strong-link cells not being wings themselves, "at least one of cellA/cellB is Y" deduction: correct. ([R2-009] is a misclassification scope issue, not a bad deduction.)

### Updated Totals After Round 2

| | Round 1 | Round 2 added | Combined |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 3 | 1 | 4 |
| Medium | 27 | 9 | 36 |
| Low | 105 | 4 | 109 |
| **Total** | **135** | **14** | **149** |

(Round 1 had 1 finding **Disputed** in Round 2 — not deducted from totals since the doc preserves it for reference; the bug it half-described is captured properly as [R2-002].)

### Recommended Round 2 Fix Order

1. **[R2-001]** (High) — fix in isolation; small change in one file; test coverage gap is straightforward to fill.
2. **R1 High items** — `incorrectMoves` inflation, `createPuzzleWithDifficulty` silent downgrade, plus their test gaps.
3. **R2 misclassification cluster** — [R2-005], [R2-006], [R2-007], [R2-009], [R2-010]. These share a theme: each technique should refuse to fire when an easier technique would catch the same pattern. Consider whether the fix is per-technique guards (simpler, what's recommended above) OR a shared `HintFinder` dispatcher change (more invasive, but addresses root cause once).
4. **[R2-003]** (architecture) — design decision needed. Discuss with user before changing.
5. **[R2-002], [R2-004], [R2-008]** — independent bug fixes.
6. **R2 Low items + R1 Medium items** — clean up at leisure.

---

## Summary

**Total findings**: 149 (135 Round 1 + 14 Round 2; 1 R1 finding Disputed by R2; 7 severity disagreements)
- **Critical**: 0
- **High**: 4 (3 R1 + 1 R2)
- **Medium**: 36 (27 R1 + 9 R2)
- **Low**: 109 (105 R1 + 4 R2)

### The High-severity items (fix first)

1. **[R2-001] `BoardState.applying` does not refresh pencil marks for `.clear` actions** — `Hints/SolveUtilities.swift:45-46`. After a Validation `.clear` hint runs, the cleared cell ends up with empty pencil marks instead of its valid options. `SolvePathEmitter` then can't find further hints for that cell; difficulty calculations under-rate the puzzle. **New in Round 2.**
2. **`Board.incorrectMoves` inflates monotonically** — `Board+Validation.swift:55-58`. After one wrong move every subsequent action bumps the counter again. PerformanceScoreCalculator consumes this as `errorCount`, so player scores are wrong any time a mistake isn't immediately corrected.
3. **`PuzzleCreator.createPuzzleWithDifficulty` silently downgrades** — `PuzzleCreator.swift:128-138`. Caller asks for `.professional`; if 20 attempts fail, returns whatever `generatePuzzle()` produces (typically `.easy`/`.medium`). API contract violated.
4. **No test covers `incorrectMoves`** — `BoardValidationTests.swift`. The Source bug above escaped because the test suite never asserts `incorrectMoves` across multiple actions. Add the test as part of the Source-side fix.

### Notable Medium-severity items (R1 highlights)

- **`apply(hint:)` produces fragmented undo history** — Board+Marking.swift:214-238. Each action saves separately; one hint = N undo steps.
- **`HoDoKuCalculator` deviates from canonical HoDoKu** with a `1.0 + 0.05 × eliminations` modifier — naming/branding question.
- **`SudokuDifficultyCalculator` falls back to AC solver** without indicating that the puzzle requires techniques beyond the hint system — under-rates such puzzles.
- **`MonthlyPuzzleManifest` timezone mismatch** — UTC vs `TimeZone.current` in `daysInMonth` and date parsing.
- **`Solution = [[Int]]` (nested array)** — significant performance opportunity if migrated to flat 81-int storage.
- **No redo capability** in `Board+UndoRedo.swift` — file is named UndoRedo but only undo exists. Confirm if this is by design.

### Notable Medium-severity items (R2 highlights)

- **[R2-002] Validation actions-vs-cells asymmetry on triple+ duplicates** — only the 2nd/3rd duplicates get clear actions while all three appear highlighted.
- **[R2-003] All hint techniques trust user-narrowed pencil marks** — `ruleOut` of a true candidate produces wrong hints.
- **[R2-005] [R2-006] [R2-007] [R2-009]** — misclassification cluster: hidden subsets misreported, locked candidates fires on hidden singles, XY-Wing/Y-Wing emit duplicate hints, W-Wing fires on naked pairs. All have correct eliminations but wrong technique labels (inflating difficulty).
- **[R2-010] Fish patterns accept partially-degenerate base lines** — Swordfish misclassification when one base line has no core positions.

### Categories breakdown (combined R1 + R2)

| Category | Count |
|---|---|
| code quality / dead code / micro-perf | ~50 |
| correctness | ~25 (was ~15; +10 from R2) |
| performance | ~20 |
| robustness / edge case | ~16 (was ~14; +2 from R2) |
| API / data integrity | ~12 |
| documentation / naming | ~13 (was ~12; +1 from R2) |
| localization | ~3 |
| concurrency / coverage gap (tests) | ~10 (was ~9; +1 from R2) |

### Files touched (audit only — Source untouched)

- `docs/audit-findings.md` (this file) — created in Round 1, extended in Round 2.
- All other files are read-only references.

### How to drive the fix work

Recommended ordering for a follow-up agent:

1. **Read the Round 2 section first** to know which Round 1 findings are Disputed or have severity disagreements.
2. **Pick a single area** at a time (e.g. Board, or Generation, or Hints/Hint Implementation). Don't try to span the whole audit in one PR.
3. **Critical/High first** (start with [R2-001]), then re-run the test suite, then move to Medium items in the same area.
4. **For each fix**: add or update a test that would have caught the bug. The tests-suite findings list specific gaps.
5. **For "design question" findings** (HoDoKu modifier, redo, Solution shape, hardestTechnique fallbacks, [R2-003] trust assumption, [R2-007] XY-vs-Y-Wing canonicalisation), confirm the intent with the user before changing semantics.
6. **For [R2] misclassification cluster** ([R2-005], [R2-006], [R2-007], [R2-009], [R2-010]): consider whether the fix is per-technique guards (simpler) or a shared `HintFinder` dispatcher change. See "Recommended Round 2 Fix Order" in the Round 2 section.
7. **Performance items**: after a meaningful batch of fixes, run the benchmarks (`swift build --product SudokuCoreBenchmarks && ./benchmark_compare.sh`) and compare against baseline. Don't optimise without measuring.

### Verification before this doc lands

- **Round 1 (2026-05-07)**: `swift test` ran after the audit completed. Result: **197 tests passed in 25 suites** (1.6s).
- **Round 2 (2026-06-02)**: No source changes made. No code commits between rounds — Round 1 findings still address current source. Round 2 verification spanned all 135 findings + a deep correctness pass on 13 hint technique files.

