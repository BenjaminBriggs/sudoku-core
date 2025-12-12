//
//  HintAction+Helpers.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

extension HintAction: Hashable {
    public static func == (lhs: HintAction, rhs: HintAction) -> Bool {
        lhs.position == rhs.position && lhs.action == rhs.action
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        switch action {
        case .solveAs(let value):
            hasher.combine(1)
            hasher.combine(value)
        case .ruleOut(let value):
            hasher.combine(2)
            hasher.combine(value)
        case .pencilIn(let value):
            hasher.combine(3)
            hasher.combine(value)
        case .clear:
            hasher.combine(4)
        }
    }
}

// Extension to make HintAction.ActionType comparable
extension HintAction.ActionType: Equatable {
    public static func == (lhs: HintAction.ActionType, rhs: HintAction.ActionType) -> Bool {
        switch (lhs, rhs) {
        case (.solveAs(let lv), .solveAs(let rv)):
            return lv == rv
        case (.ruleOut(let lv), .ruleOut(let rv)):
            return lv == rv
        case (.pencilIn(let lv), .pencilIn(let rv)):
            return lv == rv
        case (.clear, .clear):
            return true
        default:
            return false
        }
    }
}
