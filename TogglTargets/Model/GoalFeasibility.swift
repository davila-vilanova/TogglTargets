//
//  GoalFeasibility.swift
//  TogglTargets
//
//  Created by David Dávila on 23.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

fileprivate let fullDay = TimeInterval(24 * 60 * 60)
fileprivate let fullWorkDay = fullDay * (2 / 3) // Admittedly subjective

enum GoalFeasibility {
    case feasible(relativeFeasibility: Double)
    case unfeasible(relativeFeasibility: Double)
    case impossible

    static func from(dayBaseline: TimeInterval) -> GoalFeasibility {
        switch dayBaseline {
        case 0..<fullWorkDay: return .feasible(relativeFeasibility: 1 - (dayBaseline / fullWorkDay))
        case fullWorkDay...fullDay: return .unfeasible(relativeFeasibility: 1 - (dayBaseline / fullDay))
        default: return .impossible
        }
    }
}

extension GoalFeasibility {
    var isFeasible: Bool {
        switch self {
        case .feasible:
            return true
        default:
            return false
        }
    }

    var isUnfeasible: Bool {
        switch self {
        case .unfeasible:
            return true
        default:
            return false
        }
    }

    var isImpossible: Bool {
        switch self {
        case .impossible:
            return true
        default:
            return false
        }
    }
}
