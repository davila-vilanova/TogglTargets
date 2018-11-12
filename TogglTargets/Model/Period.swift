//
//  Period.swift
//  TogglTargets
//
//  Created by David Dávila on 03.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

/// Represents a period of time delimited by a start and an end.
/// The period includes the start and end days.
struct Period {
    /// The components of the first day of the period.
    let start: DayComponents

    /// The components of the last day of the period.
    let end: DayComponents
}

extension Period: Equatable {
    static func == (lhs: Period, rhs: Period) -> Bool {
        return lhs.start == rhs.start
            && lhs.end == rhs.end
    }
}
