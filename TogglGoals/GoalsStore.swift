//
//  GoalsStore.swift
//  TogglGoals
//
//  Created by David Davila on 01.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import SQLite
import ReactiveSwift

class GoalsStore {
    private let db: Connection

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<Int64>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    private var goalProperties = Dictionary<Int64, MutableProperty<TimeGoal?>>()

    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "goalsdb.sqlite3", relativeTo: baseDirectory)
            db = try Connection(databaseURL.absoluteString)
            ensureTableCreated()
        } catch {
            return nil
        }
    }

    func goalProperty(for projectId: Int64) -> MutableProperty<TimeGoal?> {
        if let property = goalProperties[projectId] {
            return property
        } else {
            let goal = retrieveGoal(for: projectId)
            let property = MutableProperty<TimeGoal?>(goal)
            property.skipRepeats{ $0 == $1 }.signal.observeValues { [unowned self] timeGoalOrNil in
                self.goalChanged(timeGoalOrNil, for: projectId)
            }
            goalProperties[projectId] = property
            return property
        }
    }

    private func goalChanged(_ timeGoalOrNil: TimeGoal?, for projectId: Int64) {
        if let modifiedGoal = timeGoalOrNil {
            print("will store goal=\(modifiedGoal)")
            storeGoal(modifiedGoal)
        } else {
            print("will delete goal for projectId=\(projectId)")
            // delete goal for captured projectId when goal is set to nil
            deleteGoal(for: projectId)
        }
    }

    private func deleteGoal(for projectId: Int64) {
        let q = goalsTable.filter(projectIdExpression == projectId)
        try! db.run(q.delete())
    }

    func goalExists(for projectId: Int64) -> Bool {
        return goalProperties[projectId]?.value != nil
    }

    private func storeGoal(_ goal: TimeGoal) {
        try! db.run(goalsTable.insert(or: .replace,
                                      projectIdExpression <- goal.projectId,
                                      hoursPerMonthExpression <- goal.hoursPerMonth,
                                      workWeekdaysExpression <- goal.workWeekdays))
        // TODO: synchronize periodically instead of writing immediately
    }

    private func ensureTableCreated() {
        try! db.run(goalsTable.create(ifNotExists: true) { t in
            t.column(idExpression, primaryKey: .autoincrement)
            t.column(projectIdExpression, unique: true)
            t.column(hoursPerMonthExpression)
            t.column(workWeekdaysExpression)
        })
    }

    private func retrieveGoal(for projectId: Int64) -> TimeGoal? {
        let q = goalsTable.filter(projectIdExpression == projectId).limit(1)
        if let row = try! db.pluck(q) {
            let projectIdValue = row[projectIdExpression]
            let hoursPerMonthValue = row[hoursPerMonthExpression]
            let workWeekdaysValue = row.get(workWeekdaysExpression) // [1]
            return TimeGoal(forProjectId: projectIdValue, hoursPerMonth: hoursPerMonthValue, workWeekdays: workWeekdaysValue)

            // [1] Can't use subscripts with custom types.
            // https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#custom-type-caveats
            // (f3da195)
        } else {
            return nil
        }
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
