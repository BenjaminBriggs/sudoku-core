# ``SudokuCore``

A comprehensive Sudoku engine for iOS and macOS with puzzle generation, solving, hints, and difficulty rating.

## Overview

SudokuCore is the engine behind a Sudoku application: the game logic, puzzle generation, solving techniques, and difficulty rating that an app builds its experience on. The package is designed for multi-platform use and includes:

- **Game State Management**: The ``Board`` class manages the entire game state with undo/redo support
- **Puzzle Generation**: Create puzzles at various difficulty levels with guaranteed unique solutions
- **Hint System**: Find solving techniques from basic to advanced patterns, each with a structured ``HintReasoning`` record for app-side presentation
- **Difficulty Rating**: Calculate puzzle difficulty using industry-standard HoDoKu and Sudoku Explainer ratings
- **Validation**: Check puzzle validity, solution uniqueness, and player progress

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:CoreConcepts>
- <doc:WorkingWithBoards>

### Core Types

- ``Board``
- ``Board/Cell``
- ``Puzzle``
- ``Puzzle/Index``
- ``PuzzleDifficulty``

### Game State Management

- ``Board/mark(positions:as:)``
- ``Board/pencil(positions:as:)``
- ``Board/advancedPencil(positions:as:)``
- ``Board/clearCell(at:)``
- ``Board/color(positions:as:)``
- ``Board/undo()``
- ``Board/undo(to:)``
- ``Board/makeCheckpoint()``
- ``UndoStep``
- ``BoardRestoration``
- ``Board/restore(_:)``
- ``Board/resetToInitialState()``

### Puzzle Generation

- <doc:GeneratingPuzzles>
- ``PuzzleCreator``
- ``SudokuGenerator``
- ``SudokuDifficultyCalculator``
- ``SolutionGenerator``

### Hints and Solving

- <doc:HintSystem>
- ``HintFinder``
- ``HintTechnique``
- ``TechniqueInfo``
- ``TechniqueID``
- ``ClassicTechniques``
- ``HintStep``
- ``HintAction``
- ``HintReasoning``
- ``HintComponent``
- ``CellFact``
- ``CandidateRef``
- ``SudokuUnit``
- ``BoardState``
- ``BoardStateParser``
- ``BoardStringFormat``

### Variants and Constraints

- <doc:ExtendingWithVariants>
- ``Constraint``
- ``AnyConstraint``
- ``ConstraintRegistry``
- ``ConstraintViolation``
- ``ConstraintDecodingError``
- ``UnknownConstraint``
- ``PuzzlePresentation``

### Rating and Performance

- <doc:DifficultyRating>
- ``SolvePathEmitter``
- ``HoDoKuCalculator``
- ``SECalculator``
- ``TimeEstimator``
- ``PersonalizedCalibrator``
- ``PerformanceScoreCalculator``

### Advanced Topics

- <doc:ValidationSystem>
- ``Validator``
- ``SudokuSolver``
