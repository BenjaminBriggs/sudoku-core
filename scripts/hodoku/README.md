# Checking the hint finder against HoDoKu

The generator only accepts puzzles the hint finder can solve, so every hint has to be right.
`HoDoKuTests` checks it against [HoDoKu](https://github.com/wyzelli/HoDoKu), an independent
solver: HoDoKu2 2.6.0, the maintained continuation of Bernhard Hobiger's original.

HoDoKu is GPL-3.0 and isn't part of this repository. `FindAll.java` links against it, so that
one file is GPL-3.0-or-later too.

## Running it

You need Java 21 or later, HoDoKu's jar and its regression test library:

```bash
scripts/hodoku/fetch.sh ~/hodoku    # downloads both from HoDoKu2 2.6.0 and checks their SHA-256
```

Then run the tests in release, since every corpus state is checked:

```bash
SUDOKU_HODOKU_JAR=~/hodoku/HoDoKu.jar SUDOKU_HODOKU_REGLIB=~/hodoku/reglib-1.3.txt \
    swift test -c release -Xswiftc -enable-testing --filter HoDoKu
```

This checks all 60 corpus puzzles at every state, that HoDoKu finds exactly one solution to
each, the one recorded, and every case in the regression test library (`HoDoKuLibraryTests`).
That library is over a thousand candidate grids collected by HoDoKu's author, each with the one
result a technique must give there, or a note that it mustn't fire. Add `SUDOKU_VERIFY_ALL=1 SUDOKU_SOAK_GENERATE=20` to include freshly
generated puzzles as well (see `GeneratedPuzzleTests`).

Without HoDoKu, `swift test` still compares every hint with HoDoKu's findings recorded in
`Tests/SudokuCoreTests/Fixtures/hodoku.json`, for the first corpus puzzle of each level at every
state, and `HoDoKuCalculator`'s estimates with HoDoKu's ratings recorded in
`Tests/SudokuCoreTests/Fixtures/hodoku-ratings.json`. After a change to the corpus or to HoDoKu's
version, rewrite both with:

```bash
SUDOKU_HODOKU_JAR=~/hodoku/HoDoKu.jar SUDOKU_HODOKU_VERSION="HoDoKu2 2.6.0" SUDOKU_UPDATE_HODOKU_FIXTURE=1 \
    swift test -c release -Xswiftc -enable-testing --filter HoDoKu
```

## What's compared

At each state, for every technique both have:

- wherever HoDoKu finds the technique, the hint finder must too;
- every placement and elimination the hint finder makes must be one HoDoKu also makes, under
  that technique or another, chains and loops included.

HoDoKu has no 4- to 7-Y-Wing, so those are checked only by the reference finders in
`ReferenceTechniques.swift`.

## Where the two differ on purpose

HoDoKu reports some steps the hint finder leaves to simpler techniques, and these are set aside:

| HoDoKu reports | The hint finder |
|---|---|
| A hidden single in a cell with one candidate | Calls it a naked single |
| A fish with a base line holding one candidate | Leaves it to the hidden single |
| A Skyscraper, Kite or Turbot Fish removing a candidate from its own cells | Leaves it to locked candidates, which always finds it |
| A W-Wing whose two cells see each other | Calls it a naked pair |
| BUG+1 while another cell holds a single candidate | Waits for the single |

A Turbot Fish with one strong link in a box and the other in a line counts as a Crane.

The hint finder also makes some deductions HoDoKu doesn't look for:

- **Unique Rectangle type 4:** HoDoKu removes b from the two corners only when a is missing from
  every cell that sees both. The usual definition, and the hint finder's, needs a confined to
  the two corners in just one unit they share.
- **Unique Rectangle type 3:** HoDoKu leaves every cell holding a or b out of the subset. Such a
  cell is still sound in it: the corner holding an extra digit and the subset's cells fill all of
  the subset's digits between them.
- **W-Wing:** HoDoKu assigns each cell of the strong link to the first wing cell it sees, so it
  misses a W-Wing where one link cell sees both. Its AICs still find these eliminations.

HoDoKu's own BUG+1 search throws on a few states. There it gives no verdict on BUG+1.

## Ratings

`HoDoKuCalculator` estimates the score and level HoDoKu gives a puzzle: the hint finder solves it
in HoDoKu's order, scoring HoDoKu's points. `HoDoKuRatingTests` asks HoDoKu to rate the puzzles in
`hodoku-ratings.json` (150 shipped puzzles the hint finder solves, 30 per level) and the corpus
puzzles, with HoDoKu's default settings, and checks the estimates over them:

- at least 85% at HoDoKu's level, and 98% within one level;
- a median score error of at most 10%, and a total within 10% of HoDoKu's.

They can't match every puzzle: HoDoKu has techniques the hint finder doesn't, such as chains,
Sue de Coq, Hidden Rectangles, Unique Rectangle type 6 and Remote Pairs, and a 4- to 7-Y-Wing
counts as the XY-Chain HoDoKu finds it as. When written, the estimates gave HoDoKu's level for
139 of the 150 recorded puzzles, and for 96% of the 3,745 shipped puzzles the hint finder solves.
The live test also checks HoDoKu still gives the recorded ratings.
