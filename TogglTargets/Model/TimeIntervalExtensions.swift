//
//  TimeIntervalExtensions.swift
//  TogglTargets
//
//  Created by David Davila on 01.10.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
