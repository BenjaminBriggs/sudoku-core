#!/usr/bin/env python3
"""Make sure the technique tests still catch known bugs.

Applies each mutation below to the source, runs the per-commit technique suites in release,
and expects them to fail. A mutation the suites miss means the tests have gone quiet. Every
file is restored afterwards, even on Ctrl-C.

Usage: scripts/mutation-check.py [name ...]    (default: all mutations)
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HINTS = "Sources/SudokuCore/Hints/Hint Implementation/"
# MUTATION_SUITES overrides which suites run, to see what one set of tests catches on its own.
SUITES = os.environ.get(
    "MUTATION_SUITES",
    "TechniqueVerificationTests|TechniqueFixtureTests|MetamorphicTests|HoDoKuTests|TechniqueLibraryTests")

# name: (file, [(original text, mutated text)], what it reintroduces)
MUTATIONS = {
    "fins-by-frequency": (HINTS + "FishPatterns.swift", [(
        "for combo in combinations(of: sortedCrossLines, choose: n) {",
        "for combo in [Array(sortedCrossLines.prefix(n))] {",
    )], "finned fish picks its core lines by frequency (the original bug)"),
    "naked-subset-off-by-one": (HINTS + "NakedSubsets.swift", [(
        "if count > 0 && count <= n {",
        "if count > 0 && count < n {",
    )], "naked subsets skip cells holding exactly n candidates"),
    "pointing-single-cell": (HINTS + "LockedPointing.swift", [(
        "if possibleRows.count == 1, let lockedRow = possibleRows.first, possiblePositions.count >= 2 {",
        "if possibleRows.count == 1, let lockedRow = possibleRows.first, possiblePositions.count > 0 {",
    )], "pointing accepts a box's lone candidate"),
    "w-wing-peers": (HINTS + "WWing.swift", [(
        "if neighboursA.contains(cellB) { return nil }",
        "",
    )], "W-Wing accepts cells that see each other"),
    "y-wing-unrestricted": (HINTS + "NYWing.swift", [(
        "guard nextUnrestricted.nonzeroBitCount <= 1 else { continue }",
        "guard nextUnrestricted.nonzeroBitCount <= 2 else { continue }",
    ), (
        "guard union.nonzeroBitCount == n, unrestricted.nonzeroBitCount == 1 else { return nil }",
        "guard union.nonzeroBitCount == n, unrestricted.nonzeroBitCount >= 1 else { return nil }",
    )], "n-Y-Wing tolerates a second unrestricted digit"),
    "ur-ignores-uniqueness": (HINTS + "UniqueRectangles.swift", [(
        "guard state.assumesUniqueSolution else { return nil }",
        "",
    )], "Unique Rectangles run on puzzles not known to be unique"),
    "crane-without-weak-link": (HINTS + "Crane.swift", [(
        "guard LookupTables.cellNeighbours[boxJoint.row][boxJoint.column].contains(lineJoint) else { continue }",
        "",
    )], "Crane skips the check that the joined ends see each other"),
    "bug-without-grave-check": (HINTS + "BUG.swift", [(
        "guard leavesBUG else { continue }",
        "",
    )], "BUG+1 places the first candidate without checking the grave"),
}


def run_suites() -> bool:
    """True when the suites pass, False when a test fails. Exits if the build breaks, since a
    mutation that doesn't compile proves nothing about the tests."""
    result = subprocess.run(
        ["swift", "test", "-c", "release", "-Xswiftc", "-enable-testing", "--filter", SUITES],
        cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode == 0:
        return True
    output = result.stdout + result.stderr
    if "Test run with" not in output:
        sys.exit("The build failed, so nothing was tested:\n" + output[-2000:])
    return False


def main(names):
    if run_suites() is False:
        sys.exit("The suites fail without any mutation; fix them first.")

    survivors = []
    for name in names:
        file, edits, meaning = MUTATIONS[name]
        path = ROOT / file
        original = path.read_text()
        mutated = original
        for old, new in edits:
            if mutated.count(old) != 1:
                sys.exit(f"{name}: the code it mutates has changed; update the mutation ({old[:60]}...)")
            mutated = mutated.replace(old, new)
        try:
            path.write_text(mutated)
            caught = run_suites() is False
        finally:
            path.write_text(original)
        print(f"{'caught  ' if caught else 'MISSED  '} {name}: {meaning}", flush=True)
        if caught is False:
            survivors.append(name)

    if survivors:
        sys.exit(f"{len(survivors)} mutation(s) survived: {', '.join(survivors)}")
    print(f"All {len(names)} mutations caught.")


if __name__ == "__main__":
    main(sys.argv[1:] or list(MUTATIONS))
