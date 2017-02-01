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
    let hoursPerMonth = Expression<Int?>("hours_per_month")
    let workDaysPerWeek = Expression<Int?>("work_days_per_week")

    init() {
        db = try! Connection("goalsdb.sqlite3")
        ensureTableCreated()
        retrieveAllGoals()
    }

    internal func retrieveGoal(projectId: Int64) -> TimeGoal? {
        return cachedGoals[projectId]
    }

    internal func storeGoal(goal: TimeGoal) {
        cachedGoals[goal.projectId] = goal
        try! db.run(goalsTable.insert(or: .replace,
                                      projectId <- goal.projectId,
                                      hoursPerMonth <- goal.hoursPerMonth,
                                      workDaysPerWeek <- goal.workDaysPerWeek))
        // TODO: synchronize periodically instead of writing immediately
    }

    private func ensureTableCreated() {
        try! db.run(goalsTable.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(projectId, unique: true)
            t.column(hoursPerMonth)
            t.column(workDaysPerWeek)
        })
    }

    private func retrieveAllGoals() {
        for retrievedGoal in try! db.prepare(goalsTable) {
            let projectIdValue = retrievedGoal[projectId]
            var goal = TimeGoal(forProjectId: projectIdValue)
            goal.hoursPerMonth = retrievedGoal[hoursPerMonth]
            goal.workDaysPerWeek = retrievedGoal[workDaysPerWeek]
            cachedGoals[projectIdValue] = goal
        }
    }
}
