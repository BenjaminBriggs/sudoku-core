# Technique testing plan

The generator's job is to accept only puzzles the hint finder can solve, so the finder has to be
provably right. Today's example tests (`HintTests`, `HintRegressionTests`) show each technique
works on cases someone wrote down. They missed the finned-fish bug, the Pointing bug (single-cell
boxes) and the W-Wing bug (bivalue cells that see each other). This plan turns example tests into
property tests over real board states.

## Where we are

Everything below is done on `claude/hint-coach-techniques-0722fa` unless an item says otherwise.
Each item's **Done** line says where it lives.

- `Tests/SudokuCoreTests/TechniqueVerification/` holds the reference finders (all 33 techniques),
  the corpus verification, fixtures, metamorphic tests, stall exhaustion, name and uniqueness
  tests, rating snapshots and the generator contract.
- `scripts/mutation-check.py` applies 8 known-bad edits; all 8 are caught.
- Per-commit: the whole core suite (260 tests) runs in about 42 s in a debug build.
- Soak: `SUDOKU_VERIFY_ALL=1 swift test -c release -Xswiftc -enable-testing` runs the 60-puzzle
  corpus at every state in about 50 s. Add `SUDOKU_SOAK_SEEDS=<folder of seed-*.json>` for the
  app's 5,000 seeds and `SUDOKU_SOAK_FAILURES=<file>` to collect failing puzzles as JSON lines.

## Phase 1: lock in what exists

1. Commit the finned-fish, Pointing and W-Wing fixes with the verification suite.
   **Done:** commit 450e7ef.
2. Write each reference definition as a doc comment that cites a source (HoDoKu or SudokuWiki),
   so a reviewer can check the reference without reading core.
   **Done:** every reference finder has a `Source:` line (HoDoKu, or Sudoku Coach for Crane and
   n-Y-Wings).
3. Delete or merge the duplicate `yWing`, which behaves identically to `xyWing`. Keep its raw value
   decodable for stored puzzles.
   **Done:** `.yWing` is gone; `HintTechnique(rawValue: "yWing")` and decoding both give `.xyWing`.
   Removing a case is source-breaking, so the next tag should be a major version.
4. Decide deliberate core choices and record them in the reference, for example "hidden single
   skips cells that are already naked singles".
   **Done:** listed in the header of `ReferenceTechniques.swift`.

## Phase 2: close the gaps in coverage

5. **Hand-made fixtures** per technique for shapes the corpus rarely shows:
   - sashimi fish and fish with two fins
   - Empty Rectangles with only two cells
   - both orientations of every pattern
   - eliminations at the edge of the pattern
   - **negative fixtures**: near-misses that must not fire

   **Done:** `TechniqueFixtureTests` has 22 hand-made boards: a positive and a near-miss for each
   new technique, a sashimi X-Wing that the old fin bug missed, the Pointing and W-Wing
   near-misses, and a real BUG+1 state. Both orientations come from the metamorphic tests rather
   than duplicated fixtures. Two-cell Empty Rectangles and two-fin fish appear in the corpus, but
   there's no dedicated fixture for them yet.
6. **Metamorphic tests.** Apply random symmetry transforms (swap rows in a band, swap bands,
   transpose, relabel digits) to a state. The hint set must transform to match: same technique,
   same eliminations after mapping. This is a cheap way to catch orientation-specific bugs.
   **Done:** `MetamorphicTests`. Each technique's reference set must map exactly. Core must fire
   on the moved board exactly when it fired before, and whatever it does there must be licensed.
7. **Exhaustion at stall points.** For every corpus puzzle that stalls, assert that no reference
   finder fires at the stall. Then "stalled" really means the puzzle is beyond our techniques.
   **Done:** `MetamorphicTests.stallsAreExhausted`.
8. **Mutation check in CI.** A small script applies known-bad patches (an old `detectFins`, an
   off-by-one in a subset size) and asserts the suite fails. This guards against the suite going
   quiet.
   **Done:** `scripts/mutation-check.py`. A broken build stops it rather than counting as caught.
   Its first run found that nothing caught a BUG+1 without the grave check, which the BUG+1
   fixture now does. There's no CI for core yet, so it runs by hand.

## Phase 3: guard the generator's contract

9. **Rating snapshots.** Pin the SE/HoDoKu rating, level and hardest technique for about 50
   puzzles. A finder change that moves ratings must update the snapshot on purpose.
   **Done:** all 60 corpus puzzles, in `Fixtures/rating-snapshots.json`. Regenerate with
   `SUDOKU_UPDATE_SNAPSHOTS=1`. The snapshot also pins the known flaw: 27 corpus puzzles still
   need guessing, and some of those rate Easy or Medium because the calculator scores only the
   partial solve.
10. **End-to-end solvability.** For generated puzzles of each level and symmetry, assert
    `needsGuessing == false` whenever the generator accepted the puzzle.
    **Done:** `GeneratorContractTests`. Per commit it covers Easy, Medium and Hard, with no symmetry
    and with 180°. The soak adds Expert, Professional, 90° and diagonal.
11. **Performance budgets.** Add a per-technique benchmark in `Benchmarks/`, with a CI threshold,
    so new finders (n-Y-Wing) don't slow generation.
    **Partly done:** `HintFinder.Stall.*` benchmarks time each new finder at a Professional stall
    point. No CI threshold yet, because there's no CI. Release numbers per stall state over 300
    stall points (measured with other work running): 7-Y-Wing 8.3 ms, 6-Y 6.0, 5-Y 3.3,
    4-Y 1.3, Crane 0.14, each UR type about 0.025, BUG+1 under 0.001. All techniques together come
    to 24 ms, against about 5 ms before the n-Y-Wings.

## Phase 4: running it

12. Two tiers:
    - **Per-commit:** the debug subset, fixtures, metamorphic tests and snapshots, in under 60 s.
    - **Nightly soak:** all 5,000 app seed puzzles plus freshly generated ones, with several
      thinned variants each, in release. Any failure writes the board state to a fixture file
      for a regression test.
    **Done**, apart from scheduling: the tiers are `CorpusPuzzle.isSoak`, the seed folder and the
    failure file above. Freshly generated puzzles go through `GeneratorContractTests`, not the full
    verification.

## Rule for new techniques

Each new technique (Crane, n-Y-Wing, UR 1–5, BUG) lands with:

- its reference finder
- positive and negative fixtures
- a metamorphic pass
- benchmark numbers

It isn't done until the verification suite runs clean on the full corpus.

All of the new techniques meet this rule. The verification suite runs clean on the full corpus,
and the stall rates on the app's seeds match an independent Python implementation exactly:
Hard 87.2%, Expert 59.0% and Pro 28.5% solved, up from 76.1%, 32.2% and 10.3%.
