//
//  GoalsStore.swift
//  TogglGoals
//
//  Created by David Davila on 01.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import SQLite
import Result
import ReactiveSwift

typealias ProjectIndexedGoals = [ProjectID : Goal]

protocol GoalsStore {
    var allGoals: Property<ProjectIndexedGoals> { get }
    
    /// Action which takes a project ID as input and returns a producer that sends a single
    /// Property value corresponding to the goal associated with the project ID.
    var readGoalAction: Action<ProjectID, Property<Goal?>, NoError> { get }

    /// Action which accepts new (or edited) goal values and stores them
    var writeGoalAction: Action<Goal, Void, NoError> { get }

    /// Action which takes a project ID as input and deletes the goal associated with that project ID
    var deleteGoalAction: Action<ProjectID, Void, NoError> { get }
}

class SQLiteGoalsStore: GoalsStore {
    private let db: Connection

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<ProjectID>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    lazy var allGoals = Property(_allGoals)
    private var _allGoals = MutableProperty(ProjectIndexedGoals())

    private let (lifetime, token) = Lifetime.make()
    private lazy var writeScheduler = QueueScheduler(name: "GoalsStore-writeScheduler")

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

    lazy var readGoalAction = Action<ProjectID, Property<Goal?>, NoError> { [unowned self] projectId in
        let goalProperty = self.allGoals.map { $0[projectId] }.skipRepeats { $0 == $1 }
        return SignalProducer(value: goalProperty)
    }

    lazy var writeGoalAction = Action<Goal, Void, NoError> { [unowned self] goal in
        self.storeGoal(goal)
        return SignalProducer.empty
    }

    lazy var deleteGoalAction = Action<ProjectID, Void, NoError> { [unowned self] projectId in
        self.deleteGoal(for: projectId)
        return SignalProducer.empty
    }

    private func storeGoal(_ goal: Goal) {
        _allGoals.value[goal.projectId] = goal
        try! db.run(goalsTable.insert(or: .replace,
                                      projectIdExpression <- goal.projectId,
                                      hoursPerMonthExpression <- goal.hoursPerMonth,
                                      workWeekdaysExpression <- goal.workWeekdays))
        // TODO: synchronize periodically instead of writing immediately
    }

    private func deleteGoal(for projectId: ProjectID) {
        _allGoals.value[projectId] = nil
        let q = goalsTable.filter(projectIdExpression == projectId)
        try! db.run(q.delete())
    }


    private func ensureTableCreated() {
        try! db.run(goalsTable.create(ifNotExists: true) { t in
            t.column(idExpression, primaryKey: .autoincrement)
            t.column(projectIdExpression, unique: true)
            t.column(hoursPerMonthExpression)
            t.column(workWeekdaysExpression)
        })
    }

    private func retrieveAllGoals() {
        var retrievedGoals = ProjectIndexedGoals()
        let retrievedRows = try! db.prepare(goalsTable)
        for retrievedRow in retrievedRows {
            let projectIdValue = retrievedRow[projectIdExpression]
            let hoursPerMonthValue = retrievedRow[hoursPerMonthExpression]
            let workWeekdaysValue = retrievedRow.get(workWeekdaysExpression) // [1]
            let goal = Goal(forProjectId: projectIdValue, hoursPerMonth: hoursPerMonthValue, workWeekdays: workWeekdaysValue)

            retrievedGoals[projectIdValue] = goal
        }

        _allGoals.value = retrievedGoals

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
