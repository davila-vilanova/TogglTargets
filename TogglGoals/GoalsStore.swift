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

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<Int64>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    private var goalProperties = Dictionary<Int64, Property<TimeGoal>>()
    private var observedGoals = Dictionary<Int64, ObservedProperty<TimeGoal>>()
    
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

    func goalProperty(for projectId: Int64) -> Property<TimeGoal> {
        if let property = goalProperties[projectId] {
            return property
        } else {
            let property = Property<TimeGoal>(value: nil) // promise to call if one is created later
            let observed = ObservedProperty<TimeGoal>(original: property, valueObserver: { [weak self] (goal) in
                guard let modifiedGoal = goal else {
                    return
                }
                self?.storeGoal(modifiedGoal)
                }, invalidationObserver: { [weak self] in
                    self?.goalProperties.removeValue(forKey: projectId)
                    self?.observedGoals.removeValue(forKey: projectId)
            })
            goalProperties[projectId] = property
            observedGoals[projectId] = observed
            
            return property
        }
    }
    
    @discardableResult
    func storeNew(goal: TimeGoal) -> Property<TimeGoal> {
        let property = goalProperty(for: goal.projectId)
        property.value = goal
        return property
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

    private func retrieveAllGoals() {
        var retrievedGoals = [TimeGoal]()
        let retrievedRows = try! db.prepare(goalsTable)
        for retrievedRow in retrievedRows {
            let projectIdValue = retrievedRow[projectIdExpression]
            let hoursPerMonthValue = retrievedRow[hoursPerMonthExpression]
            let workWeekdaysValue = retrievedRow.get(workWeekdaysExpression) // [1]
            let goal = TimeGoal(forProjectId: projectIdValue, hoursPerMonth: hoursPerMonthValue, workWeekdays: workWeekdaysValue)
            
            retrievedGoals.append(goal)
        }
        
        for goal in retrievedGoals {
            let property = goalProperty(for: goal.projectId)
            property.value = goal
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
