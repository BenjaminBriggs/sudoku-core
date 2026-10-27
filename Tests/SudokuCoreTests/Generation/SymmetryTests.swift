import Testing
@testable import SudokuCore

struct SymmetryTests {
    private let solvedGrid: [[Int]] = [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9]
    ]

    private static let symmetric = Symmetry.allCases.filter { $0 != .none }

    // MARK: - Orbits

    @Test("Orbits partition the grid", arguments: Symmetry.allCases)
    func orbitsPartitionGrid(_ symmetry: Symmetry) {
        let cells = symmetry.orbits.flatMap { $0 }
        #expect(cells.count == 81)
        #expect(Set(cells).count == 81)
    }

    @Test("Every cell's orbit contains it and agrees with the partition", arguments: Symmetry.allCases)
    func orbitOfCellIsConsistent(_ symmetry: Symmetry) {
        for index in Puzzle.Index.allIndices {
            let orbit = symmetry.orbit(of: index)
            #expect(orbit.contains(index))
            for member in orbit {
                #expect(Set(symmetry.orbit(of: member)) == Set(orbit))
            }
        }
    }

    @Test("Orbit counts match each symmetry's fixed cells")
    func orbitCounts() {
        #expect(Symmetry.none.orbits.count == 81)
        #expect(Symmetry.rotational180.orbits.count == 41)  // 40 pairs + centre
        #expect(Symmetry.rotational90.orbits.count == 21)  // 20 quads + centre
        #expect(Symmetry.mirrorHorizontal.orbits.count == 45)  // 36 pairs + middle row
        #expect(Symmetry.mirrorVertical.orbits.count == 45)
        #expect(Symmetry.diagonal.orbits.count == 45)
        #expect(Symmetry.antiDiagonal.orbits.count == 45)
        #expect(Symmetry.orthogonal.orbits.count == 25)  // 16 quads + 8 pairs on the centre lines + centre
        #expect(Symmetry.diagonals.orbits.count == 25)  // 16 quads + 8 pairs on the diagonals + centre
        #expect(Symmetry.rotational180.orbit(of: Puzzle.Index(row: 4, column: 4)).count == 1)
    }

    @Test("Composite orbits are the union of their two mirrors' orbits")
    func compositeOrbits() {
        #expect(Set(Symmetry.orthogonal.orbit(of: Puzzle.Index(row: 0, column: 1))) == [
            Puzzle.Index(row: 0, column: 1), Puzzle.Index(row: 8, column: 1),
            Puzzle.Index(row: 0, column: 7), Puzzle.Index(row: 8, column: 7),
        ])
        #expect(Set(Symmetry.orthogonal.orbit(of: Puzzle.Index(row: 4, column: 1))) == [
            Puzzle.Index(row: 4, column: 1), Puzzle.Index(row: 4, column: 7),
        ])
        #expect(Set(Symmetry.diagonals.orbit(of: Puzzle.Index(row: 0, column: 1))) == [
            Puzzle.Index(row: 0, column: 1), Puzzle.Index(row: 1, column: 0),
            Puzzle.Index(row: 7, column: 8), Puzzle.Index(row: 8, column: 7),
        ])
        #expect(Set(Symmetry.diagonals.orbit(of: Puzzle.Index(row: 2, column: 2))) == [
            Puzzle.Index(row: 2, column: 2), Puzzle.Index(row: 6, column: 6),
        ])
        for (composite, parts) in [(Symmetry.orthogonal, [Symmetry.mirrorHorizontal, .mirrorVertical]),
                                   (.diagonals, [.diagonal, .antiDiagonal])] {
            for index in Puzzle.Index.allIndices {
                let orbit = Set(composite.orbit(of: index))
                for part in parts {
                    #expect(Set(part.orbit(of: index)).isSubset(of: orbit))
                }
                #expect(Set(Symmetry.rotational180.orbit(of: index)).isSubset(of: orbit))
            }
        }
    }

    // MARK: - Detection

    @Test("A full grid has every symmetry")
    func fullGridHasEverySymmetry() {
        #expect(Symmetry.symmetries(of: solvedGrid) == Self.symmetric)
    }

    @Test("Detection finds only the symmetries the layout has")
    func detectsRotational180Only() {
        var grid = solvedGrid
        grid[0][1] = 0
        grid[8][7] = 0
        #expect(Symmetry.symmetries(of: grid) == [.rotational180])

        grid[1][8] = 0
        grid[7][0] = 0
        #expect(Symmetry.symmetries(of: grid) == [.rotational180, .rotational90])
    }

    @Test("Detection rejects an asymmetric layout")
    func asymmetricLayout() {
        var grid = solvedGrid
        grid[0][1] = 0
        #expect(Symmetry.symmetries(of: grid).isEmpty)
    }

    @Test("Detection reports a composite with everything it implies")
    func detectsComposites() {
        var orthogonal = solvedGrid
        for index in Symmetry.orthogonal.orbit(of: Puzzle.Index(row: 0, column: 1)) {
            orthogonal[index.row][index.column] = 0
        }
        #expect(Symmetry.symmetries(of: orthogonal) == [.rotational180, .mirrorHorizontal, .mirrorVertical, .orthogonal])

        var diagonals = solvedGrid
        for index in Symmetry.diagonals.orbit(of: Puzzle.Index(row: 0, column: 1)) {
            diagonals[index.row][index.column] = 0
        }
        #expect(Symmetry.symmetries(of: diagonals) == [.rotational180, .diagonal, .antiDiagonal, .diagonals])

        // One mirror alone isn't the composite
        var horizontal = solvedGrid
        horizontal[0][1] = 0
        horizontal[8][1] = 0
        #expect(Symmetry.symmetries(of: horizontal) == [.mirrorHorizontal])
    }

    // MARK: - Generation

    @Test("Symmetric generation is unique and keeps its symmetry", arguments: symmetric)
    func generatedPuzzlesAreUniqueAndSymmetric(_ symmetry: Symmetry) async {
        for _ in 0..<5 {
            let solution = SolutionGenerator.generateRandomSolution()
            let puzzle = await SudokuGenerator.createPuzzle(
                from: solution,
                targetEmpty: 64,
                symmetry: symmetry
            )
            #expect(Validator.hasUniqueSolution(puzzle))
            #expect(symmetry.isSatisfied(by: puzzle))
            #expect(Symmetry.symmetries(of: puzzle).contains(symmetry))
            // Givens come from the solution
            for index in Puzzle.Index.allIndices where puzzle[index.row][index.column] != 0 {
                #expect(puzzle[index.row][index.column] == solution[index.row][index.column])
            }
        }
    }

    @Test("Symmetric generation never exceeds the target")
    func symmetricRespectsTarget() async {
        let puzzle = await SudokuGenerator.createPuzzle(
            from: solvedGrid,
            targetEmpty: 7,
            symmetry: .rotational90,
            uniqueCheck: { _ in true }
        )
        let empty = puzzle.flatMap { $0 }.filter { $0 == 0 }.count
        // Quads fill 4, then the centre fills the 5th; the next quad would overshoot
        #expect(empty == 5)
        #expect(Symmetry.rotational90.isSatisfied(by: puzzle))
    }

    @Test("Removing an orbit keeps uniqueness and symmetry")
    func removingOrbit() async {
        let solution = SolutionGenerator.generateRandomSolution()
        let puzzle = await SudokuGenerator.createPuzzle(
            from: solution, targetEmpty: 30, symmetry: .rotational180)
        let harder = try! #require(SudokuGenerator.removingOrbit(from: puzzle, symmetry: .rotational180))
        let before = puzzle.flatMap { $0 }.filter { $0 == 0 }.count
        let after = harder.flatMap { $0 }.filter { $0 == 0 }.count
        #expect(after > before)
        #expect(Validator.hasUniqueSolution(harder))
        #expect(Symmetry.rotational180.isSatisfied(by: harder))
    }

    @Test("createPuzzleWithDifficulty honours symmetry", arguments: [Symmetry.rotational180, .rotational90])
    func puzzleCreatorSymmetry(_ symmetry: Symmetry) async throws {
        let puzzle = try await PuzzleCreator.createPuzzleWithDifficulty(
            .medium, maxAttempts: 5, symmetry: symmetry)
        #expect(Validator.hasUniqueSolution(puzzle.startingState))
        #expect(symmetry.isSatisfied(by: puzzle.startingState))
    }

    // MARK: - .none is unchanged

    /// Recorded from `SudokuGenerator.createPuzzle` before symmetry existed.
    @Test("`.none` output is unchanged for a fixed removal order")
    func noneMatchesGolden() async {
        let order: [Puzzle.Index] = (0..<81).map { i in
            let offset = (i * 37 + 11) % 81
            return Puzzle.Index(row: offset / 9, column: offset % 9)
        }
        let golden = "500600010070000048100002500000700000020850001003000806900000284000019000005086000"

        let implicit = await SudokuGenerator.createPuzzle(
            from: solvedGrid, targetEmpty: 58, cellsOrder: order)
        let explicit = await SudokuGenerator.createPuzzle(
            from: solvedGrid, targetEmpty: 58, cellsOrder: order, symmetry: .none)

        #expect(implicit.flatString(empty: "0") == golden)
        #expect(explicit.flatString(empty: "0") == golden)
    }
}
