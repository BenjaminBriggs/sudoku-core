//
//  PuzzleIndexNeighboursTests.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 26/02/2025.
//


import Testing
@testable import SudokuCore

struct PuzzleIndexNeighboursTests {

    @Test("neighbour(in:) returns correct neighbours for a middle index")
    @MainActor
    func testMiddleIndexNeighbours() {
        let index = Puzzle.Index(row: 4, column: 4)
        
        let right = index.neighbour(in: .right)
        #expect(right == Puzzle.Index(row: 4, column: 5))
        
        let left = index.neighbour(in: .left)
        #expect(left == Puzzle.Index(row: 4, column: 3))
        
        let top = index.neighbour(in: .top)
        #expect(top == Puzzle.Index(row: 3, column: 4))
        
        let bottom = index.neighbour(in: .bottom)
        #expect(bottom == Puzzle.Index(row: 5, column: 4))
        
        let topRight = index.neighbour(in: .topRight)
        #expect(topRight == Puzzle.Index(row: 3, column: 5))
        
        let topLeft = index.neighbour(in: .topLeft)
        #expect(topLeft == Puzzle.Index(row: 3, column: 3))
        
        let bottomRight = index.neighbour(in: .bottomRight)
        #expect(bottomRight == Puzzle.Index(row: 5, column: 5))
        
        let bottomLeft = index.neighbour(in: .bottomLeft)
        #expect(bottomLeft == Puzzle.Index(row: 5, column: 3))
    }

    @Test("neighbour(in:) returns nil for out-of-bound directions at the top-left corner")
    @MainActor
    func testTopLeftCornerNeighbours() {
        let index = Puzzle.Index(row: 0, column: 0)
        
        #expect(index.neighbour(in: .left) == nil)
        #expect(index.neighbour(in: .top) == nil)
        #expect(index.neighbour(in: .topLeft) == nil)
        #expect(index.neighbour(in: .topRight) == nil)
        
        let right = index.neighbour(in: .right)
        #expect(right == Puzzle.Index(row: 0, column: 1))
        
        let bottom = index.neighbour(in: .bottom)
        #expect(bottom == Puzzle.Index(row: 1, column: 0))
        
        let bottomRight = index.neighbour(in: .bottomRight)
        #expect(bottomRight == Puzzle.Index(row: 1, column: 1))
        
        #expect(index.neighbour(in: .bottomLeft) == nil)
    }

    @Test("allNeighbours returns only cardinal neighbours for a middle index")
    @MainActor
    func testAllNeighboursMiddleIndex() {
        let index = Puzzle.Index(row: 4, column: 4)
        let neighbours = index.allNeighbours
        let expected: Set<Puzzle.Index> = [
            Puzzle.Index(row: 4, column: 5),
            Puzzle.Index(row: 4, column: 3),
            Puzzle.Index(row: 3, column: 4),
            Puzzle.Index(row: 5, column: 4)
        ]
        #expect(Set(neighbours) == expected)
        #expect(neighbours.count == 4)
    }

    @Test("allNeighbours returns only available cardinal neighbours for a top-edge index")
    @MainActor
    func testAllNeighboursTopEdge() {
        let index = Puzzle.Index(row: 0, column: 4)
        let neighbours = index.allNeighbours
        // For (0,4): right -> (0,5), left -> (0,3), top -> nil, bottom -> (1,4)
        let expected: [Puzzle.Index] = [
            Puzzle.Index(row: 0, column: 5),
            Puzzle.Index(row: 0, column: 3),
            Puzzle.Index(row: 1, column: 4)
        ]
        #expect(neighbours == expected)
    }
}