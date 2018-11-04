//
//  TimeIntervalExtensions.swift
//  TogglTargets
//
//  Created by David Davila on 01.10.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

private let secondsInHour: Double = 3600
private let secondsInMinute: Double = 60
private let millisecondsInSecond: Double = 1000

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

    static func from(minutes: Double) -> TimeInterval {
        return TimeInterval(minutes * secondsInMinute)
    }

    static func from(milliseconds: Double) -> TimeInterval {
        return milliseconds / millisecondsInSecond
    }
}
