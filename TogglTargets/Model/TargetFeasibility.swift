//
//  TargetFeasibility.swift
//  TogglTargets
//
//  Created by David Dávila on 23.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

/// The amount of seconds in a (regular) day.
private let fullDay = TimeInterval(24 * 60 * 60)

private let fullWorkDay = fullDay * (2 / 3) // Admittedly subjective

/// Represents the feasibility of reaching a time target based on the amount of time per day that should be worked.
enum TargetFeasibility {

    /// Target is feasible: the time needed to work per day falls below the unfeasibility threshold.
    case feasible(relativeFeasibility: Double)

    /// Target is unfeasible but not impossible: the time needed to work per day falls below the unfeasibility threshold
    /// but below the impossibility threshold.
    case unfeasible(relativeFeasibility: Double)

    /// Reaching the target is impossible: there are literally not enough hours in a day.
    case impossible

    /// Determines the feasibility of reaching a target according to the provided day baseline.
    ///
    /// - parameters:
    ///   - dayBaseline: The amount of time needed to work per day to reach the time target.
    ///
    /// - returns: The determine feasibility.
    static func from(dayBaseline: TimeInterval) -> TargetFeasibility {
        switch dayBaseline {
        case 0..<fullWorkDay: return .feasible(relativeFeasibility: 1 - (dayBaseline / fullWorkDay))
        case fullWorkDay...fullDay: return .unfeasible(relativeFeasibility: 1 - (dayBaseline / fullDay))
        default: return .impossible
        }
    }
}

extension TargetFeasibility {
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
