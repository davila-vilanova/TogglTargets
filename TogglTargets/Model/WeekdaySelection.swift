//
//  WeekdaySelection.swift
//  TogglTargets
//
//  Created by David Dávila on 18.10.17.
//  Copyright © 2017 davi. All rights reserved.
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
    var previous: Weekday {
        switch self.rawValue {
        case 0: return Weekday.allCases.last!
        default: return Weekday(rawValue: self.rawValue - 1)!
        }
    }
}

extension Weekday {
    var indexInGregorianCalendar: Int {
        return rawValue + 1
    }
    static func fromIndexInGregorianCalendar(_ index: Int) -> Weekday? {
        return Weekday(rawValue: index - 1)
    }
    var indexInGregorianCalendarSymbolsArray: Int {
        return rawValue
    }
    static func fromIndexInGregorianCalendarSymbolsArray(_ index: Int) -> Weekday? {
        return Weekday(rawValue: index)
    }
}

struct WeekdaySelection {
    private var selectionDict = [Weekday: Bool]()

    mutating func select(_ day: Weekday) {
        selectionDict[day] = true
    }

    mutating func deselect(_ day: Weekday) {
        selectionDict[day] = false
    }

    func isSelected(_ day: Weekday) -> Bool {
        if let selection = selectionDict[day] {
            return selection
        } else {
            return false
        }
    }

    var countOfSelectedDays: Int {
        return selectionDict.filter { $0.1 }.count
    }

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
    static var exceptWeekend: WeekdaySelection {
        return WeekdaySelection(selectedDays: [.monday,
                                               .tuesday, .wednesday, .thursday, .friday])
    }

    static var wholeWeek: WeekdaySelection {
        return WeekdaySelection(selectedDays: Set(Weekday.allCases))
    }

    static var empty: WeekdaySelection {
        return WeekdaySelection(selectedDays: [])
    }

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
    static func < (lhs: WeekdaySelection, rhs: WeekdaySelection) -> Bool {
        return lhs.countOfSelectedDays < rhs.countOfSelectedDays
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

extension WeekdaySelection {
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
