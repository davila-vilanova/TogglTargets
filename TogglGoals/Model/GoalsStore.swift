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
typealias ReadGoalAction = Action<ProjectID, Property<Goal?>, NoError>
typealias WriteGoalAction = Action<Goal, (), NoError>
typealias DeleteGoalAction = Action<ProjectID, (), NoError>

protocol GoalsStore {
    /// Action which takes a project ID as input and returns a producer that sends a single
    /// Property value corresponding to the goal associated with the project ID.
    var readGoalAction: ReadGoalAction { get }

    /// Action which accepts new (or edited) goal values and stores them
    var writeGoalAction: WriteGoalAction { get }

    /// Action which takes a project ID as input and deletes the goal associated with that project ID
    var deleteGoalAction: DeleteGoalAction { get }

    var projectIDs: BindingTarget<[ProjectID]> { get }
    var projectIDsByGoalsUpdates: SignalProducer<ProjectIDsByGoals.Update, NoError> { get }
}

class SQLiteGoalsStore: GoalsStore {
    private let db: Connection

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<ProjectID>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    private let allGoals = MutableProperty<ProjectIndexedGoals?>(nil)

    private func connectInputsToAllGoals() {
        allGoals <~ modifyGoalAction.values.map { $0.indexedGoals }
    }

    private let (lifetime, token) = Lifetime.make()
    private lazy var scheduler = QueueScheduler()

    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "goalsdb.sqlite3", relativeTo: baseDirectory)
            db = try Connection(databaseURL.absoluteString)
            ensureTableCreated()
            connectInputsToAllGoals()
            connectInputsToMGAState()
            retrieveAllGoals()
        } catch {
            return nil
        }
    }

    lazy var readGoalAction = ReadGoalAction { [unowned self] projectId in
        let goalProperty = self.allGoals.map { $0?[projectId] }.skipRepeats { $0 == $1 }
        return SignalProducer(value: goalProperty)
    }

    lazy var writeGoalAction = WriteGoalAction(enabledIf: modifyGoalAction.isEnabled) {
        [modifyGoalAction] goal in
        _ = modifyGoalAction.applySerially((goal, goal.projectId)).start()
        return SignalProducer.empty
    }

    lazy var deleteGoalAction = DeleteGoalAction(enabledIf: modifyGoalAction.isEnabled) {
        [modifyGoalAction] projectId in
        _ = modifyGoalAction.applySerially((nil, projectId)).start()
        return SignalProducer.empty
    }

    var projectIDs: BindingTarget<[ProjectID]> { return _projectIDs.deoptionalizedBindingTarget }
    private var _projectIDs = MutableProperty<[ProjectID]?>(nil)

    var projectIDsByGoalsUpdates: SignalProducer<ProjectIDsByGoals.Update, NoError> {
        return SignalProducer.merge(fullRefreshUpdateProducer.map { ProjectIDsByGoals.Update.full($0) },
                                    modifyGoalAction.values.producer.map { ProjectIDsByGoals.Update.createGoal($0.update) })
    }

    private lazy var fullRefreshUpdateProducer: SignalProducer<ProjectIDsByGoals, NoError> = {
       return _projectIDs.producer.skipNil().combineLatest(with: allGoals.producer.skipNil())
            .skipRepeats { (old, new) -> Bool in // let through only changes in project IDs, order insensitive
                let oldIds = Set(old.0)
                let newIds = Set(new.0)
                return oldIds == newIds
            }
            .map(ProjectIDsByGoals.init)
    }()

    private let mgaState = MutableProperty<(ProjectIndexedGoals, ProjectIDsByGoals)?>(nil)
    private func connectInputsToMGAState() {
        let allGoalsProducer = allGoals.producer.skipNil()
        let projectIDsByGoalsProducer = SignalProducer.merge(fullRefreshUpdateProducer,
                                                             modifyGoalAction.values.producer.map { $0.projectIDsByGoals })
        mgaState <~ allGoalsProducer.combineLatest(with: projectIDsByGoalsProducer)
    }

    private lazy var modifyGoalAction = Action<(Goal?, ProjectID), ProjectIDsByGoals.ModifyGoalOutput, NoError>(unwrapping: mgaState) {
        [unowned self] (state, input) in
        let (allGoals, projectIDsByGoalsPre) = state
        let (goalPost, projectId) = input
        let output = try! projectIDsByGoalsPre.afterEditingGoal(goalPost, for: projectId, in: allGoals)
        let update = output.update

        self.scheduler.schedule { [goal = goalPost, projectId, unowned self] in
            switch update {
            case .create: fallthrough
            case .update:
                self.storeGoal(goal!)
            case .remove:
                self.deleteGoal(for: projectId)
            }
        }
        return SignalProducer(value: output)
    }

    private func storeGoal(_ goal: Goal) {
        try! db.run(goalsTable.insert(or: .replace,
                                      projectIdExpression <- goal.projectId,
                                      hoursPerMonthExpression <- goal.hoursPerMonth,
                                      workWeekdaysExpression <- goal.workWeekdays))
        // TODO: synchronize periodically instead of writing immediately
    }

    private func deleteGoal(for projectId: ProjectID) {
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
            let goal = Goal(forProjectId: projectIdValue,
                            hoursPerMonth: hoursPerMonthValue,
                            workWeekdays: workWeekdaysValue)
            retrievedGoals[projectIdValue] = goal
        }

        allGoals <~ SignalProducer(value: retrievedGoals)

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

