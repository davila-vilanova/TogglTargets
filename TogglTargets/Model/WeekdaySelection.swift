//
//  WeekdaySelection.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
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

/// Represents the days of the week.
enum Weekday: Int, CaseIterable {
    case sunday = 0
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

extension Weekday {
    /// The weekday that comes before this.
    var previous: Weekday {
        switch self.rawValue {
        case 0: return Weekday.allCases.last!
        default: return Weekday(rawValue: self.rawValue - 1)!
        }
    }
}

extension Weekday {
    /// The 1-based index of this weekday, starting from 1 for Sunday.
    var indexInGregorianCalendar: Int {
        return rawValue + 1
    }

    /// Returns the weekday corresponding to the provided index, where 1 corresponds to Sunday and 7 to Saturday.
    ///
    /// - parameters:
    ///   - index: An index no smaller than 1 and no greater than 7.
    ///
    /// - returns: The corresponding weekday.
    static func fromIndexInGregorianCalendar(_ index: Int) -> Weekday? {
        return Weekday(rawValue: index - 1)
    }

    /// The zero-based index of this weekday, starting from 0 for Sunday.
    var indexInGregorianCalendarSymbolsArray: Int {
        return rawValue
    }

    /// Returns the weekday corresponding to the provided index, where 0 corresponds to Sunday and 6 to Saturday.
    ///
    /// - parameters:
    ///   - index: An index no smaller than 0 and no greater than 6.
    ///
    /// - returns: The corresponding weekday.
    static func fromIndexInGregorianCalendarSymbolsArray(_ index: Int) -> Weekday? {
        return Weekday(rawValue: index)
    }
}

/// Represents the selected state of each weekday.
struct WeekdaySelection {
    private var selectionDict = [Weekday: Bool]()

    /// Marks a weekday as selected.
    ///
    /// - parameters:
    ///   - day: The weekday to select.
    mutating func select(_ day: Weekday) {
        selectionDict[day] = true
    }

    /// Marks a weekday as not selected.
    ///
    /// - parameters:
    ///   - day: The weekday to deselect.
    mutating func deselect(_ day: Weekday) {
        selectionDict[day] = false
    }

    /// Checks whether the provided weekday is selected.
    ///
    /// - parameters:
    ///   - day: The day whose selected status to check.
    ///
    /// - returns: True if day is selected, false otherwise.
    func isSelected(_ day: Weekday) -> Bool {
        if let selection = selectionDict[day] {
            return selection
        } else {
            return false
        }
    }

    /// The count of weekdays marked as selected.
    var countOfSelectedDays: Int {
        return selectionDict.filter { $0.1 }.count
    }

    /// Initializes a new `WeekdaySelection` setting as selected any weekdays contained in the provided set.
    ///
    /// - parameters:
    ///   - selectedDays: The days to initially mark as selected.
    init(selectedDays: Set<Weekday>) {
        for day in selectedDays {
            select(day)
        }
    }
}

extension WeekdaySelection: CustomDebugStringConvertible {
    var debugDescription: String {
        var desc: String = "WeekdaySelection("
        let count = countOfSelectedDays
        if count == 0 {
            desc += "no days selected"
        } else if count == Weekday.allCases.count {
            desc += "all days selected"
        } else {
            for day in Weekday.allCases {
                desc += isSelected(day) ? "O" : "X"
            }
        }
        desc += ")"

        return desc
    }
}

extension WeekdaySelection {
    /// Each access returns a new selection that has all weekdays except for Saturday and Sunday initially marked as
    /// selected.
    static var exceptWeekend: WeekdaySelection {
        return WeekdaySelection(selectedDays: [.monday, .tuesday, .wednesday, .thursday, .friday])
    }

    /// Each access returns a new selection that has all weekdays initially marked as selected.
    static var wholeWeek: WeekdaySelection {
        return WeekdaySelection(selectedDays: Set(Weekday.allCases))
    }

    /// Each access returns a new selection that has all weekdays initially marked as not selected.
    static var empty: WeekdaySelection {
        return WeekdaySelection(selectedDays: [])
    }

    /// Returns a new selection that has a single day initially marked as selected.
    ///
    /// - parameters:
    ///   - day: The day to initially mark as selected in the new selection.
    ///
    /// - returns: A new selection with `day` already marked as selected.
    static func singleDay(_ day: Weekday) -> WeekdaySelection {
        return WeekdaySelection(selectedDays: [day])
    }
}

extension WeekdaySelection: Equatable {
    static func == (lhs: WeekdaySelection, rhs: WeekdaySelection) -> Bool {
        for day in Weekday.allCases {
            if lhs.isSelected(day) != rhs.isSelected(day) {
                return false
            }
        }
        return true
    }
}

extension WeekdaySelection: Comparable {
    /// Selection A is considered smaller than B only if A has fewer days marked as selected then B has.
    static func < (lhs: WeekdaySelection, rhs: WeekdaySelection) -> Bool {
        return lhs.countOfSelectedDays < rhs.countOfSelectedDays
    }

}

extension WeekdaySelection {
    /// Determines whether this delection has marked as selected the weekday corresponding to the provided date,
    /// interpreted using the provided calendar.
    ///
    /// - parameters:
    ///   - date: The date to check.
    ///   - calendar: The calendar to use to interpret `date` according to the calendar's timezone.
    ///
    /// - returns: True if this selection has marked as selected the corresponding weekday, false otherwise.
    func includesDay(in date: Date, accordingTo calendar: Calendar) -> Bool {
        let dateComponents = calendar.dateComponents([.weekday], from: date)
        guard let weekdayIndex = dateComponents.weekday,
            let weekday = Weekday.fromIndexInGregorianCalendar(weekdayIndex) else {
            return false
        }
        return isSelected(weekday)
    }
}

extension WeekdaySelection {
    /// Returns all the weekdays that this selection has marked as selected.
    var selectedWeekdays: [Weekday] {
        var retval = [Weekday]()
        for day in Weekday.allCases {
            if isSelected(day) {
                retval.append(day)
            }
        }
        return retval
    }
}
