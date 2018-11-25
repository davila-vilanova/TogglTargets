//
//  WeekdaySelection+Value.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
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
import SQLite

extension WeekdaySelection: Value {
    typealias Datatype = Int64

    static var declaredDatatype: String {
        return Int64.declaredDatatype
    }

    static func fromDatatypeValue(_ datatypeValue: Datatype) -> WeekdaySelection {
        return WeekdaySelection(integerRepresentation: IntegerRepresentationType(datatypeValue))
    }

    var datatypeValue: Datatype {
        return Datatype(integerRepresentation)
    }
}

extension WeekdaySelection {
    typealias IntegerRepresentationType = UInt8
    var integerRepresentation: IntegerRepresentationType {
        get {
            var int = IntegerRepresentationType(0)
            let orderedDays = Weekday.allCases
            assert(orderedDays.count >= MemoryLayout<IntegerRepresentationType>.size)

            for day in orderedDays {
                if isSelected(day) {
                    int = int | IntegerRepresentationType(1 << day.rawValue)
                }
            }
            return int
        }

        set {
            let orderedDays = Weekday.allCases
            assert(orderedDays.count >= MemoryLayout<IntegerRepresentationType>.size)

            for day in orderedDays {
                if (newValue & IntegerRepresentationType(1 << day.rawValue)) != 0 {
                    select(day)
                }
            }
        }
    }

    init(integerRepresentation: IntegerRepresentationType) {
        self.integerRepresentation = integerRepresentation
    }
}
