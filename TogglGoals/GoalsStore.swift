//
//  GoalsStore.swift
//  TogglGoals
//
//  Created by David Davila on 01.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import SQLite

class GoalsStore {
    private let db: Connection

    private var cachedGoals = Dictionary<Int64, TimeGoal>()

    let goalsTable = Table("time_goal")
    let id = Expression<Int64>("id")
    let projectId = Expression<Int64>("project_id")
    let hoursPerMonth = Expression<Int>("hours_per_month")
    let workWeekdays = Expression<WeekdaySelection>("work_weekdays")

    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "goalsdb.sqlite3", relativeTo: baseDirectory)
            db = try Connection(databaseURL.absoluteString)
            ensureTableCreated()
            retrieveAllGoals()
        } catch {
            return nil
        }
    }

    internal func retrieveGoal(projectId: Int64) -> TimeGoal? {
        return cachedGoals[projectId]
    }

    internal func storeGoal(goal: TimeGoal) {
        cachedGoals[goal.projectId] = goal
        try! db.run(goalsTable.insert(or: .replace,
                                      projectId <- goal.projectId,
                                      hoursPerMonth <- goal.hoursPerMonth,
                                      workWeekdays <- goal.workWeekdays))
        // TODO: synchronize periodically instead of writing immediately
    }

    private func ensureTableCreated() {
        try! db.run(goalsTable.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(projectId, unique: true)
            t.column(hoursPerMonth)
            t.column(workWeekdays)
        })
    }

    private func retrieveAllGoals() {
        for retrievedGoal in try! db.prepare(goalsTable) {
            let projectIdValue = retrievedGoal[projectId]
            let hoursPerMonthValue = retrievedGoal[hoursPerMonth]
            let workWeekdaysValue = retrievedGoal.get(workWeekdays) // [1]
            let goal = TimeGoal(forProjectId: projectIdValue, hoursPerMonth: hoursPerMonthValue, workWeekdays: workWeekdaysValue)

            cachedGoals[projectIdValue] = goal
        }
        // [1] Can't use subscripts with custom types. 
        // https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#custom-type-caveats
        // (f3da195)
    }
}

extension WeekdaySelection: Value {
    typealias Datatype = Int64

    static var declaredDatatype: String {
        get {
            return Int64.declaredDatatype
        }
    }

    static func fromDatatypeValue(_ datatypeValue: Datatype) -> WeekdaySelection {
        return WeekdaySelection(integerRepresentation: IntegerRepresentationType(datatypeValue))
    }

    var datatypeValue: Datatype {
        get {
            return Datatype(integerRepresentation)
        }
    }

}
