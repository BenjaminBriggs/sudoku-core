# ``SudokuCore``

A comprehensive Sudoku engine for iOS and macOS with puzzle generation, solving, hints, and difficulty rating.

## Overview

SudokuCore provides everything needed to build a complete Sudoku application, from puzzle generation to advanced solving techniques. The package is designed for multi-platform use and includes:

- **Game State Management**: The ``Board`` class manages the entire game state with undo/redo support
- **Puzzle Generation**: Create puzzles at various difficulty levels with guaranteed unique solutions
- **Hint System**: Find and explain solving techniques from basic to advanced patterns
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
- ``Board/undo()``
- ``Board/UndoStep``

### Puzzle Generation

- <doc:GeneratingPuzzles>
- ``SudokuGenerator``
- ``SudokuDifficultyCalculator``
- ``SolutionGenerator``

### Hints and Solving

- <doc:HintSystem>
- ``HintFinder``
- ``HintTechnique``
- ``HintStep``
- ``HintAction``

### Advanced Topics

- <doc:DifficultyRating>
- <doc:ValidationSystem>
- ``SudokuValidator``