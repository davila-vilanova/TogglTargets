//
//  Project.swift
//  TogglGoals
//
//  Created by David Davila on 24/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

struct Profile {
    let id: Int64
    var name: String?
    var email: String?
    var imageUrl: URL?
    var timeZone:String?

    init(id: Int64) {
        self.id = id
    }
}

typealias StringKeyedDictionary = Dictionary<String, Any>

extension Profile {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Profile? {
        if let id = dictionary["id"] as? Int64 {
            var profile = Profile(id: id)
            if let name = dictionary["fullname"] as? String {
                profile.name = name
            }
            if let email = dictionary["email"] as? String {
                profile.email = email
            }
            if let imageUrlString = dictionary["image_url"] as? String,
                let imageUrl = URL(string: imageUrlString) {
                profile.imageUrl = imageUrl
            }

            return profile
        } else {
            return nil
        }
    }
}

struct Workspace {
    let id: Int64
    var name: String?

    init(id: Int64) {
        self.id = id
    }
}

extension Workspace {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Workspace? {
        if let id = dictionary["id"] as? Int64 {
            var workspace = Workspace(id: id)
            if let name = dictionary["name"] as? String {
                workspace.name = name
            }
            return workspace
        } else {
            return nil
        }
    }

    static func collectionFromTogglAPI(dictionaries: [StringKeyedDictionary]) -> [Workspace] {
        var workspaces = Array<Workspace>()
        for workspaceDictionary in dictionaries {
            if let workspace = Workspace.fromTogglAPI(dictionary: workspaceDictionary) {
                workspaces.append(workspace)
            }
        }
        return workspaces
    }
}

struct Project {
    let id: Int64
    var name: String?
    var active: Bool?
    var workspaceId: Int64?

    init(id: Int64) {
        self.id = id
    }
}

extension Project {
    static func fromTogglAPI(dictionary: StringKeyedDictionary) -> Project? {
        if let id = dictionary["id"] as? Int64 {
            var project = Project(id: id)
            if let name = dictionary["name"] as? String {
                project.name = name
            }
            if let active = dictionary["active"] as? Bool {
                project.active = active
            }
            if let workspaceId = dictionary["wid"] as? Int64 {
                project.workspaceId = workspaceId
            }
            return project
        }
        return nil
    }

    static func collectionFromTogglAPI(dictionaries: [StringKeyedDictionary]) -> [Project] {
        var projects = Array<Project>()
        for projectDictionary in dictionaries {
            if let project = Project.fromTogglAPI(dictionary: projectDictionary) {
                projects.append(project)
            }
        }
        return projects
    }
}

enum Weekday: Int {
    case sunday = 0
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    static let allDays: Set<Weekday> = {
        var days = Set<Weekday>()
        var dayIndex = 0
        while let day = Weekday(rawValue: dayIndex) {
            days.insert(day)
            dayIndex += 1
        }
        return days
    }()

    static let allDaysOrdered: Array<Weekday> = {
        var days = Array<Weekday>()
        var dayIndex = 0
        while let day = Weekday(rawValue: dayIndex) {
            days.append(day)
            dayIndex += 1
        }
        return days
    }()
}

struct WeekdaySelection {
    private var selectionDict = Dictionary<Weekday, Bool>()

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
        var count = 0
        for (_, isSelected) in selectionDict {
            if isSelected {
                count += 1
            }
        }
        return count
    }
}

extension WeekdaySelection: CustomDebugStringConvertible {
    var debugDescription: String {
        var desc: String = "WeekdaySelection("
        let count = countOfSelectedDays
        if count == 0 {
            desc += "no days selected"
        } else if count == Weekday.allDays.count {
            desc += "all days selected"
        } else {
            for day in Weekday.allDaysOrdered {
                desc += isSelected(day) ? "O" : "X"
            }
        }
        desc += ")"

        return desc
    }
}

extension WeekdaySelection {
    static var exceptWeekend: WeekdaySelection {
        get {
            var s = wholeWeek
            s.deselect(.saturday)
            s.deselect(.sunday)
            return s
        }
    }

    static var wholeWeek: WeekdaySelection {
        get {
            var s = WeekdaySelection()
            for day in Weekday.allDays {
                s.select(day)
            }
            return s
        }
    }

    static func singleDay(_ day: Weekday) -> WeekdaySelection {
        var s = WeekdaySelection()
        s.select(day)
        return s
    }
}

extension WeekdaySelection: Equatable {
    static func ==(lhs: WeekdaySelection, rhs: WeekdaySelection) -> Bool {
        for day in Weekday.allDays {
            if lhs.isSelected(day) != rhs.isSelected(day) {
                return false
            }
        }
        return true
    }
}

extension WeekdaySelection {
    typealias IntegerRepresentationType = UInt8
    var integerRepresentation: IntegerRepresentationType {
        get {
            var int = IntegerRepresentationType(0)
            let orderedDays = Weekday.allDaysOrdered
            assert(orderedDays.count >= MemoryLayout<IntegerRepresentationType>.size)

            for day in orderedDays {
                if isSelected(day) {
                    int = int | IntegerRepresentationType(1 << day.rawValue)
                }
            }
            return int
        }

        set {
            let orderedDays = Weekday.allDaysOrdered
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

struct TimeGoal {
    let projectId: Int64
    var hoursPerMonth: Int
    var workWeekdays: WeekdaySelection

    init(forProjectId projectId: Int64, hoursPerMonth: Int, workWeekdays: WeekdaySelection) {
        self.projectId = projectId
        self.hoursPerMonth = hoursPerMonth
        self.workWeekdays = workWeekdays
    }
}

extension TimeGoal: CustomDebugStringConvertible {
    var debugDescription: String {
        get {
            return "Goal(forProjectId: \(projectId), hoursPerMonth: \(hoursPerMonth), workWeekdays: \(workWeekdays))"
        }
    }
}

protocol TimeReport {
    var projectId: Int64 { get }
    var since: DayComponents { get }
    var until: DayComponents { get }
    var workedTime: TimeInterval { get }
}

struct SingleTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    let workedTime: TimeInterval
}

struct TwoPartTimeReport: TimeReport {
    let projectId: Int64
    let since: DayComponents
    let until: DayComponents
    var workedTime: TimeInterval {
        return workedTimeUntilYesterday + workedTimeToday
    }
    let workedTimeUntilYesterday: TimeInterval
    let workedTimeToday: TimeInterval
}

extension SingleTimeReport: CustomDebugStringConvertible {
    var debugDescription: String {
        return "SingleTimeReport(workedTime: \(workedTime))";
    }
}

extension TwoPartTimeReport: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TwoPartTimeReport(workedTime: \(workedTime))";
    }
}

struct RunningEntry {
    let id: Int64
    let projectId: Int64
    let start: Date
    let retrieved: Date
}
