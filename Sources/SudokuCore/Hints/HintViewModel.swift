//
//  HintViewModel 2.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

@Observable
@MainActor
public final class HintViewModel {
    private var currentHintTask: Task<Void, Never>?

    public init() {
        self.boardState = BoardState()
        Task { await lookForHints() }
    }

    public init(board: Board) {
        self.boardState = board.state
        Task { await lookForHints() }
    }

    public var boardState: BoardState {
        didSet {
            if oldValue != boardState {
                Task { await lookForHints() }
            }
        }
    }

    public func lookForHints() async {
        // Cancel any existing hint-finding task
        currentHintTask?.cancel()
        availableHints = []
        // Create a new task for this hint search
        let task = Task { [weak self] in
            guard let self else { return }
            var newHints = [HintStep]()
            let state = self.boardState

            do {
                try await withThrowingTaskGroup(of: HintStep?.self) { group in
                    // Add each technique search as a child task
                    for technique in HintTechnique.orderedCases {
                        group.addTask {
                            // Check for cancellation before searching
                            try Task.checkCancellation()
                            return HintFinder.findHint(for: technique, in: state)
                        }
                    }

                    // Collect results as they complete
                    for try await result in group {
                        if let hint = result {
                            newHints.append(hint)
                        }
                        // Check for cancellation after each result
                        try Task.checkCancellation()
                    }
                }

                // Only update if we haven't been cancelled
                if Task.isCancelled == false {
                    // Sort hints to maintain technique priority order
                    newHints.sort { a, b in
                        guard let aIndex = HintTechnique.orderedCases.firstIndex(of: a.technique),
                              let bIndex = HintTechnique.orderedCases.firstIndex(of: b.technique) else {
                            return false
                        }
                        return aIndex < bIndex
                    }
                    self.availableHints = newHints
                }
            } catch {
                // Task was cancelled or other error occurred
                if (error is CancellationError) == false {
                    print("Error finding hints: \(error)")
                }
            }
        }

        currentHintTask = task
    }

    public internal(set) var availableHints: [HintStep] = []

    public var currentHint: HintStep? {
        return availableHints.first
    }

    public func hint(for technique: HintTechnique) -> HintStep? {
        availableHints.first { $0.technique == technique }
    }

    public var activeHint: HintStep?
    public var activeHintHighlight: [HintExplanationStepHighlight] = []
}
