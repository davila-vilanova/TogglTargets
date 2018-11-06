//
//  Period.swift
//  TogglTargets
//
//  Created by David Dávila on 03.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct Period {
    let start: DayComponents
    let end: DayComponents
}

extension Period: Equatable {
    static func == (lhs: Period, rhs: Period) -> Bool {
        return lhs.start == rhs.start
            && lhs.end == rhs.end
    }
}
