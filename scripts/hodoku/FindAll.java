// SPDX-License-Identifier: GPL-3.0-or-later
//
// FindAll.java: asks HoDoKu (https://github.com/wyzelli/HoDoKu, GPL-3.0) about puzzles and
// candidate states, so SudokuCore's tests can compare their hints with an independent solver.
// It links against HoDoKu's classes, so unlike the rest of this repository it is licensed
// under the GPL, version 3 or later. HoDoKu itself is not part of this repository.
//
// Run with Java 21 or later:
//   java $SORT -cp HoDoKu.jar FindAll.java states  < states.tsv  > steps.tsv
//   java $SORT -cp HoDoKu.jar FindAll.java puzzles < puzzles.tsv > solutions.tsv
//   java $SORT -cp HoDoKu.jar FindAll.java rate    < puzzles.tsv > ratings.tsv
// where SORT=-Djava.util.Arrays.useLegacyMergeSort=true. HoDoKu sorts its steps with a
// comparison that isn't consistent on some states, and Java's default sort throws
// "Comparison method violates its general contract!" there. The legacy sort doesn't check;
// it can't be switched on from main, since the JVM has sorted by then.
//
// states: each input line is key TAB grid (81 digits, 0 for empty) TAB 81 comma-separated
// candidate lists. For each, prints every step HoDoKu finds, one per line:
//   key TAB type TAB eliminations TAB placements TAB HoDoKu's description
// where eliminations and placements are "row column digit;" lists (0-based row and column),
// then key TAB END. The search covers singles, locked candidates, subsets, basic, finned and
// Franken fish up to size 4, single-digit patterns, wings, uniqueness tests, BUG+1, X- and
// XY-chains, nice loops and AICs.
//
// puzzles: each input line is key TAB grid. Prints key TAB number of solutions (stopping at
// 2) TAB the solution when there is exactly one.
//
// rate: each input line is key TAB grid. Solves it with HoDoKu's default settings and prints
// key TAB 1 if solved, else 0 TAB score TAB level (EASY to EXTREME) TAB the step types used,
// space-separated.

import java.io.*;
import java.util.*;
import generator.*;
import solver.*;
import sudoku.*;

public class FindAll {
    public static void main(String[] args) throws Exception {
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        // HoDoKu prints its own messages to stdout; keep stdout for results.
        PrintWriter out = new PrintWriter(new BufferedWriter(new OutputStreamWriter(System.out)));
        System.setOut(System.err);

        String line;
        if (args.length > 0 && args[0].equals("rate")) {
            // HoDoKu's own settings, so the rating is the one HoDoKu gives.
            SudokuSolver solver = SudokuSolverFactory.getDefaultSolverInstance();
            while ((line = in.readLine()) != null) {
                String[] p = line.split("\t");
                Sudoku2 s = new Sudoku2();
                s.setSudoku(p[1].replace('0', '.'));
                solver.setSudoku(s);
                boolean solved = solver.solve();
                StringBuilder types = new StringBuilder();
                for (SolutionStep step : solver.getSteps()) {
                    if (types.length() > 0) types.append(' ');
                    types.append(step.getType().getArgName());
                }
                out.println(p[0] + "\t" + (solved ? 1 : 0) + "\t" + solver.getScore() + "\t"
                        + solver.getSudoku().getLevel().getType().name() + "\t" + types);
            }
            out.flush();
            System.exit(0);
        }
        // A Unique Rectangle needs both of its digits in all four corners.
        Options.getInstance().setAllowUniquenessMissingCandidates(false);

        if (args.length > 0 && args[0].equals("puzzles")) {
            SudokuGenerator generator = SudokuGeneratorFactory.getDefaultGeneratorInstance();
            while ((line = in.readLine()) != null) {
                String[] p = line.split("\t");
                Sudoku2 s = new Sudoku2();
                s.setSudoku(p[1].replace('0', '.'));
                int count = generator.getNumberOfSolutions(s, 2);
                StringBuilder solution = new StringBuilder();
                if (count == 1) {
                    for (int d : generator.getSolution()) solution.append(d);
                }
                out.println(p[0] + "\t" + count + "\t" + solution);
            }
            out.flush();
            // HoDoKu's generator leaves a background thread running.
            System.exit(0);
        }

        SudokuStepFinder finder = new SudokuStepFinder();
        while ((line = in.readLine()) != null) {
            String[] p = line.split("\t");
            String key = p[0], grid = p[1];
            String[] candidates = p[2].split(",", -1);
            Sudoku2 s = new Sudoku2();
            s.setSudoku(grid.replace('0', '.'));
            for (int i = 0; i < 81; i++) {
                if (grid.charAt(i) != '0') continue;
                for (int d = 1; d <= 9; d++) {
                    if (s.isCandidate(i, d) && candidates[i].indexOf((char) ('0' + d)) < 0) s.delCandidate(i, d);
                }
            }
            List<SolutionStep> all = new ArrayList<>();
            all.addAll(finder.findAllFullHouses(s.clone()));
            all.addAll(finder.findAllNakedSingles(s.clone()));
            all.addAll(finder.findAllHiddenSingles(s.clone()));
            all.addAll(finder.findAllLockedCandidates1(s.clone()));
            all.addAll(finder.findAllLockedCandidates2(s.clone()));
            all.addAll(finder.findAllNakedXle(s.clone()));
            all.addAll(finder.findAllHiddenXle(s.clone()));
            // Basic fish (type 0), then Franken fish (type 1): sizes 2 to 4, up to 5 fins.
            all.addAll(finder.getAllFishes(s.clone(), 2, 4, 5, 0, null, -1, 0));
            all.addAll(finder.getAllFishes(s.clone(), 2, 4, 5, 2, null, -1, 1));
            all.addAll(finder.findAllSkyScrapers(s.clone()));
            all.addAll(finder.findAllTwoStringKites(s.clone()));
            all.addAll(finder.findAllEmptyRectangles(s.clone()));
            all.addAll(finder.getAllWings(s.clone()));
            all.addAll(finder.getAllUniqueness(s.clone()));
            all.addAll(finder.getAllChains(s.clone()));
            all.addAll(finder.getAllNiceLoops(s.clone()));
            // BUG+1 has no find-all, and there is at most one. HoDoKu's search throws on some
            // states; report that rather than stop.
            try {
                finder.setSudoku(s.clone());
                SolutionStep bug = finder.getStep(SolutionType.BUG_PLUS_1);
                if (bug != null) all.add(bug);
            } catch (RuntimeException e) {
                out.println(key + "\tbug1-error\t\t\t" + e);
            }
            for (SolutionStep step : all) {
                StringBuilder eliminations = new StringBuilder(), placements = new StringBuilder();
                for (Candidate c : step.getCandidatesToDelete()) {
                    eliminations.append(c.getIndex() / 9).append(' ').append(c.getIndex() % 9).append(' ').append(c.getValue()).append(';');
                }
                if (step.getType().isSingle()) {
                    for (int i : step.getIndices()) {
                        placements.append(i / 9).append(' ').append(i % 9).append(' ').append(step.getValues().get(0)).append(';');
                    }
                }
                out.println(key + "\t" + step.getType().getArgName() + "\t" + eliminations + "\t" + placements
                        + "\t" + step.toString(2).replaceAll("\\s+", " "));
            }
            out.println(key + "\tEND");
        }
        out.flush();
        System.exit(0);
    }
}
