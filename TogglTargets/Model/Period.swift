//
//  Period.swift
//  TogglTargets
//
//  Created by David Dávila on 03.11.17.
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
