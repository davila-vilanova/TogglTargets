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

protocol GoalsStore {
    var allGoals: Property<[ProjectID : Goal]> { get }
    func goalProperty(for projectId: ProjectID) -> Property<Goal?>
    func goalBindingTarget(for projectId: ProjectID) -> BindingTarget<Goal?>
    func goalExists(for projectId: ProjectID) -> Bool
}

class SQLiteGoalsStore: GoalsStore {
    private let db: Connection

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<ProjectID>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    lazy var allGoals = Property(_allGoals)
    private var _allGoals = MutableProperty([ProjectID : Goal]())

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

    func goalProperty(for projectId: ProjectID) -> Property<Goal?> {
        return _allGoals.map { $0[projectId] }.skipRepeats { $0 == $1 }
    }

    func goalBindingTarget(for projectId: ProjectID) -> BindingTarget<Goal?> {
        return BindingTarget<Goal?>(on: writeScheduler, lifetime: lifetime) { [unowned self] in
            self.goalChanged($0, for: projectId)
        }
    }

    private func goalChanged(_ timeGoalOrNil: Goal?, for projectId: ProjectID) {
        if let modifiedGoal = timeGoalOrNil {
            print("will store goal=\(modifiedGoal)")
            storeGoal(modifiedGoal)
        } else {
            print("will delete goal for projectId=\(projectId)")
            // delete goal for captured projectId when goal is set to nil
            deleteGoal(for: projectId)
        }
        _allGoals.value[projectId] = timeGoalOrNil
    }

    private func deleteGoal(for projectId: ProjectID) {
        let q = goalsTable.filter(projectIdExpression == projectId)
        try! db.run(q.delete())
    }

    func goalExists(for projectId: ProjectID) -> Bool {
        return goalProperty(for: projectId).value != nil
    }

    private func storeGoal(_ goal: Goal) {
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

    private func retrieveAllGoals() {
        var retrievedGoals = [ProjectID : Goal]()
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
