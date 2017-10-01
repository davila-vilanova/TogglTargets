//
//  TimeIntervalExtensions.swift
//  TogglGoals
//
//  Created by David Davila on 01.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

fileprivate let secondsInHour: Double = 3600

extension TimeInterval {
    var toHours: Double {
        return self / secondsInHour
    }
    static func from(hours: Double) -> TimeInterval {
        return TimeInterval(hours * secondsInHour)
    }
    static func from(hours: Int) -> TimeInterval {
        return from(hours: Double(hours))
    }
}
