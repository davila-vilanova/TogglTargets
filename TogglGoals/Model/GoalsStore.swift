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

    private let (lifetime, token) = Lifetime.make()
    private lazy var scheduler = QueueScheduler()

    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "goalsdb.sqlite3", relativeTo: baseDirectory)
            db = try Connection(databaseURL.absoluteString)
            ensureTableCreated()
            connectInputsToAllGoals()
            connectInputsToMGActionState()
            retrieveAllGoals()
        } catch {
            return nil
        }
    }

    // MARK: - Public actions

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


    // MARK: - Generation of ProjectIDsByGoals

    var projectIDs: BindingTarget<[ProjectID]> { return _projectIDs.deoptionalizedBindingTarget }
    private var _projectIDs = MutableProperty<[ProjectID]?>(nil)

    private let allGoals = MutableProperty<ProjectIndexedGoals?>(nil)

    private func connectInputsToAllGoals() {
        allGoals <~ modifyGoalAction.values.map { $0.3 }
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

    private typealias MGActionState = (ProjectIndexedGoals, ProjectIDsByGoals)
    private typealias MGActionInput = (Goal?, ProjectID)
    private typealias MGActionOutput = (PersistedGoalUpdate, ProjectIDsByGoals.Update.GoalUpdate, ProjectIDsByGoals, ProjectIndexedGoals)

    private let mgActionState = MutableProperty<MGActionState?>(nil)
    private func connectInputsToMGActionState() {
        let allGoalsProducer = allGoals.producer.skipNil()
        let projectIDsByGoalsProducer = SignalProducer.merge(fullRefreshUpdateProducer,
                                                             modifyGoalAction.values.producer.map { $0.2 })
        mgActionState <~ allGoalsProducer.combineLatest(with: projectIDsByGoalsProducer)
    }

    private lazy var modifyGoalAction = Action<MGActionInput, MGActionOutput, NoError>(unwrapping: mgActionState) {
        (state, input) in
        let (currentIndexedGoals, currentIDsByGoals) = state
        let (newGoalOrNil, projectId) = input
        let oldGoal = currentIndexedGoals[projectId]

        let newIndexedGoals: ProjectIndexedGoals = {
            var t = currentIndexedGoals
            t[projectId] = newGoalOrNil
            return t
        }()

        let idsByGoalsUpdate = ProjectIDsByGoals.Update.GoalUpdate.forGoalChange(affecting: currentIDsByGoals,
                                                                                 for: projectId,
                                                                                 from: oldGoal,
                                                                                 producing: newIndexedGoals)!

        let persistedGoalUpdate: PersistedGoalUpdate = { [goal = newGoalOrNil] in
            switch (idsByGoalsUpdate) {
            case .create: return .create(goal!)
            case .update: return .update(goal!)
            case .remove: return .delete(projectId)
            }
        }()

        let output = (persistedGoalUpdate, idsByGoalsUpdate, idsByGoalsUpdate.apply(to: currentIDsByGoals), newIndexedGoals)
        return SignalProducer(value: output)
    }

    var projectIDsByGoalsUpdates: SignalProducer<ProjectIDsByGoals.Update, NoError> {
        return SignalProducer.merge(fullRefreshUpdateProducer.map { ProjectIDsByGoals.Update.full($0) },
                                    modifyGoalAction.values.producer.map { ProjectIDsByGoals.Update.createGoal($0.1) })
    }


    // MARK: -

    private enum PersistedGoalUpdate {
        case create(Goal)
        case update(Goal)
        case delete(ProjectID)
    }

    private lazy var persistedGoalUpdates: BindingTarget<PersistedGoalUpdate> = {
        let target = BindingTarget<PersistedGoalUpdate>(on: scheduler, lifetime: lifetime) {
            [unowned self] update in
            switch update {
            case .create(let goal):
                self.storeGoal(goal)
            case .update(let goal):
                self.storeGoal(goal)
            case .delete(let projectId):
                self.deleteGoal(for: projectId)
            }
        }
        target <~ modifyGoalAction.values.map { $0.0 }
        return target
    }()

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

