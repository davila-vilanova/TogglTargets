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

/// Update the value the goal associated to the project ID matching the provided goal's
/// `projectId` property. Returns a producer that completes immediately.
typealias WriteGoalAction = Action<Goal, Void, NoError>

/// Delete the goal associated to the provided project ID. Returns a producer that
/// completes immediately.
typealias DeleteGoalAction = Action<ProjectID, Void, NoError>

/// Producer of `ProjectIDsByGoals.Update` values that when started emits a
// `full(ProjectIDsByGoals)` value which can be followed by full or
/// incremental updates.
typealias ProjectIDsByGoalsProducer = SignalProducer<ProjectIDsByGoals.Update, NoError>

/// An entity that stores and retrieves Goal values
protocol GoalsStore {

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the goal associated with that
    /// project ID.
    ///
    /// - note: `nil` goal values represent a goal that does not exist yet or
    ///         that has been deleted.
    var readGoal: (ProjectID) -> SignalProducer<Goal?, NoError> { get }

    /// Action which accepts new (or edited) goal values and stores them.
    var writeGoalAction: WriteGoalAction { get }

    /// Action which takes a project ID as input and deletes the goal associated with that project ID.
    var deleteGoalAction: DeleteGoalAction { get }
}

/// An entity that receives a stream of collections of project IDs and produces a stream of
/// `ProjectIDsByGoals` values and incremental updates generated by matching the received project IDs
/// against the goals and changes to the goals it has knowledge of.
protocol ProjectIDsByGoalsProducing {
    /// Target that accepts and array of unsorted project IDs that will be matched against the goals
    /// that this store has knowledge of.
    var projectIDs: BindingTarget<[ProjectID]> { get }

    /// Producer of `ProjectIDsByGoals.Update` values that when started emits a
    // `full(ProjectIDsByGoals)` value which can be followed by full or
    /// incremental updates, corresponding to the `ProjectIDsByGoals` generated
    /// by matching project IDs provided to the `projectIDs` target against the
    /// goals this store knows about.
    var projectIDsByGoalsProducer: ProjectIDsByGoalsProducer { get }
}

/// Represents an entity that conforms to both the `GoalsStore` and `ProjectIDsByGoalsProducing` protocols.
protocol ProjectIDsByGoalsProducingGoalsStore: GoalsStore, ProjectIDsByGoalsProducing { }

class SQLiteGoalsStore: ProjectIDsByGoalsProducingGoalsStore {
    /// The database connection used to store and retrieve goals.
    private let db: Connection

    // MARK: - Table and expression entities

    private let goalsTable = Table("time_goal")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<ProjectID>("project_id")
    private let hoursPerMonthExpression = Expression<Int>("hours_per_month")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    private let (lifetime, token) = Lifetime.make()
    private lazy var scheduler = QueueScheduler()

    /// Initialize an instance that will read and write its database in the provided base directory.
    /// If no database file exists under the provided directory it will create one.
    /// Returns `nil` if the database file cannot be opened and cannot be created.
    ///
    /// - parameters:
    ///   - baseDirectory: The `URL` of the directory from which to read and to which to write
    ///     the database used by this instance.
    init?(baseDirectory: URL?) {
        do {
            let databaseURL = URL(fileURLWithPath: "goalsdb.sqlite3", relativeTo: baseDirectory)
            db = try Connection(databaseURL.absoluteString)
        } catch {
            return nil
        }

        let writeGoalProducer = _writeGoal.producer.skipNil()
        let deleteGoalProducer = _deleteGoal.producer.skipNil()

        let singleGoalUpdateComputer = Property(
            initial: nil,
            then: SignalProducer.combineLatest(goalsRetrievedFromDatabase.output, projectIDsByGoalsFullRefresh)
                .map { [unowned self] (indexedGoalsState, projectIDsByGoalsState) in
                    SingleGoalUpdateComputer(initialStateIndexedGoals: indexedGoalsState,
                                             initialStateProjectIDsByGoals: projectIDsByGoalsState,
                                             inputWriteGoal: writeGoalProducer,
                                             inputDeleteGoal: deleteGoalProducer,
                                             outputProjectIDsByGoalsUpdate: self.projectIDsByGoalsLastSingleUpdate.deoptionalizedBindingTarget)
            }
        )

        let indexedGoalsState = Property(
            initial: nil,
            then: goalsRetrievedFromDatabase.output.producer
                .map { [unowned self] retrievedGoals in
                    IndexedGoalsState(initialStateIndexedGoals: retrievedGoals,
                                      inputWriteGoal: writeGoalProducer.logEvents(identifier: "writeGoalProducer2", events: [.value]),
                                      inputDeleteGoal: deleteGoalProducer,
                                      outputIndexedGoals: self.allGoals.deoptionalizedBindingTarget)
            }
        )

        lifetime.observeEnded {
            _ = singleGoalUpdateComputer
            _ = indexedGoalsState
        }

        writeGoalInDatabase <~ writeGoalProducer
        deleteGoalFromDatabase <~ deleteGoalProducer

        ensureSchemaCreated()
        retrieveAllGoals()
    }

    // MARK: - All goals kept in memory

    /// Tracks the values of all goals indexed by project ID.
    private let allGoals = MutableProperty<ProjectIndexedGoals?>(nil)

    // MARK: - Goal interface

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the goal associated with that
    /// project ID.
    ///
    /// - note: `nil` goal values represent a goal that does not exist yet or
    ///         that has been deleted.
    lazy var readGoal = { (projectID: ProjectID) -> SignalProducer<Goal?, NoError> in
        self.allGoals.producer.map { $0?[projectID] }.skipRepeats { $0 == $1 }
    }

    // MARK: - Public actions

    /// Action which accepts new (or edited) goal values and stores them.
    lazy var writeGoalAction = WriteGoalAction {
        self._writeGoal.value = $0
        return SignalProducer.empty
    }

    /// Action which takes a project ID as input and deletes the goal associated with that project ID.
    lazy var deleteGoalAction = DeleteGoalAction {
        self._deleteGoal.value = $0
        return SignalProducer.empty
    }

    var writeGoal: BindingTarget<Goal> { return _writeGoal.deoptionalizedBindingTarget }
    private let _writeGoal = MutableProperty<Goal?>(nil)

    var deleteGoal: BindingTarget<ProjectID> { return _deleteGoal.deoptionalizedBindingTarget }
    private let _deleteGoal = MutableProperty<ProjectID?>(nil)


    // MARK: - Generation of ProjectIDsByGoals

    /// Target that accepts an array of unsorted project IDs that will be matched against the goals
    /// that this store has knowledge of.
    var projectIDs: BindingTarget<[ProjectID]> { return _projectIDs.deoptionalizedBindingTarget }

    /// The value backer for the `projectIDs` target.
    private var _projectIDs = MutableProperty<[ProjectID]?>(nil)

    /// Produces a new `ProjectIDsByGoals` value each time a value is sent to the `projectIDs` target
    /// that contains a different set of unique IDs than the last seen one.
    private lazy var projectIDsByGoalsFullRefresh: SignalProducer<ProjectIDsByGoals, NoError> =
        _projectIDs.producer.skipNil().combineLatest(with: allGoals.producer.skipNil())
            .skipRepeats { (old, new) -> Bool in // let through only changes in project IDs, order insensitive
                let oldIds = Set(old.0)
                let newIds = Set(new.0)
                return oldIds == newIds
            }
            .map(ProjectIDsByGoals.init)

    /// Used to connect the output of the current `SingleGoalUpdateComputer`
    /// to `projectIDsByGoalsProducer`.
    private let projectIDsByGoalsLastSingleUpdate = MutableProperty<ProjectIDsByGoals.Update.GoalUpdate?>(nil)


    /// Producer of `ProjectIDsByGoals.Update` values that when started emits a
    // `full(ProjectIDsByGoals)` value which can be followed by by full or
    /// incremental updates, corresponding to the `ProjectIDsByGoals` generated
    /// by matching project IDs provided to the `projectIDs` target against the
    /// goals this store knows about.
    lazy var projectIDsByGoalsProducer: ProjectIDsByGoalsProducer =
        SignalProducer.merge(
            // Send a full value and any full value updates that happen from now on
            projectIDsByGoalsFullRefresh.map (ProjectIDsByGoals.Update.full),
            // Send any updates to a single goal that happen from now on
            projectIDsByGoalsLastSingleUpdate.producer.skipNil().map (ProjectIDsByGoals.Update.singleGoal)
    )


    // MARK: -

    private let goalsRetrievedFromDatabase = Signal<ProjectIndexedGoals, NoError>.pipe()

    private lazy var writeGoalInDatabase = BindingTarget<(Goal)>(on: scheduler, lifetime: lifetime) { [weak self] in
        self?.storeGoal($0)
    }

    private lazy var deleteGoalFromDatabase = BindingTarget<(ProjectID)>(on: scheduler, lifetime: lifetime) { [weak self] in
        self?.deleteGoal(for: $0)
    }

    /// Stores the provided goal into the database synchronously.
    private func storeGoal(_ goal: Goal) {
        try! db.run(goalsTable.insert(or: .replace,
                                      projectIdExpression <- goal.projectId,
                                      hoursPerMonthExpression <- goal.hoursPerMonth,
                                      workWeekdaysExpression <- goal.workWeekdays))
        // TODO: synchronize periodically instead of writing immediately
    }

    /// Deletes synchronously from the database the goal corresponding to the
    /// provided project ID.
    private func deleteGoal(for projectId: ProjectID) {
        let q = goalsTable.filter(projectIdExpression == projectId)
        try! db.run(q.delete())
    }

    /// Creates the underlying database schema if not already created.
    private func ensureSchemaCreated() {
        try! db.run(goalsTable.create(ifNotExists: true) { t in
            t.column(idExpression, primaryKey: .autoincrement)
            t.column(projectIdExpression, unique: true)
            t.column(hoursPerMonthExpression)
            t.column(workWeekdaysExpression)
        })
    }

    /// Retrieves all goals from the database and stores them in the value of the `allGoals` property.
    private func retrieveAllGoals() {
        var retrievedGoals = ProjectIndexedGoals()
        let retrievedRows = try! db.prepare(goalsTable)
        for retrievedRow in retrievedRows {
            let projectIdValue = retrievedRow[projectIdExpression]
            let hoursPerMonthValue = retrievedRow[hoursPerMonthExpression]
            let workWeekdaysValue = try! /* TODO */ retrievedRow.get(workWeekdaysExpression) // [1]
            let goal = Goal(forProjectId: projectIdValue,
                            hoursPerMonth: hoursPerMonthValue,
                            workWeekdays: workWeekdaysValue)
            retrievedGoals[projectIdValue] = goal
        }

        goalsRetrievedFromDatabase.input.send(value: retrievedGoals)

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

// MARK : -

fileprivate class SingleGoalUpdateComputer {
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()

    init(initialStateIndexedGoals: ProjectIndexedGoals,
         initialStateProjectIDsByGoals: ProjectIDsByGoals,
         inputWriteGoal: SignalProducer<Goal, NoError>,
         inputDeleteGoal: SignalProducer<ProjectID, NoError>,
         outputProjectIDsByGoalsUpdate: BindingTarget<ProjectIDsByGoals.Update.GoalUpdate>) {

        indexedGoals = initialStateIndexedGoals
        projectIDsByGoals = initialStateProjectIDsByGoals

        writeGoal <~ inputWriteGoal
        deleteGoal <~ inputDeleteGoal

        lifetime += outputProjectIDsByGoalsUpdate <~ projectIDsByGoalsUpdatePipe.output

        let description = "\(self)"
        print("\(description) started")

        lifetime.observeEnded {
            print("\(description) ended")
        }
    }

    // MARK: - State

    private var indexedGoals: ProjectIndexedGoals
    private var projectIDsByGoals: ProjectIDsByGoals

    // MARK: - Input

    private lazy var writeGoal = BindingTarget<Goal>(on: scheduler, lifetime: lifetime) { [weak self] in
        self?.computeAndUpdate(newGoal: $0, projectID: $0.projectId)
    }

    private lazy var deleteGoal = BindingTarget<ProjectID>(on: scheduler, lifetime: lifetime) { [weak self] in
        self?.computeAndUpdate(newGoal: nil, projectID: $0)
    }

    private func computeAndUpdate(newGoal: Goal?, projectID: ProjectID) {
        // Compute update
        assert(projectIDsByGoals.sortedProjectIDs.contains(projectID), "projectID must be included in projectIDsByGoals")
        let update = ProjectIDsByGoals.Update.GoalUpdate
            .forGoalChange(involving: newGoal,
                           for: projectID,
                           within: indexedGoals,
                           affecting: projectIDsByGoals)! // returns nil only if `projectID` is not included in `projectIDsByGoals`


        // Update internal state
        indexedGoals[projectID] = newGoal
        projectIDsByGoals = update.apply(to: projectIDsByGoals)

        // Send update
        projectIDsByGoalsUpdatePipe.input.send(value: update)
    }

    // MARK: - Output

    private let projectIDsByGoalsUpdatePipe = Signal<ProjectIDsByGoals.Update.GoalUpdate, NoError>.pipe()
}

// MARK: -

fileprivate class IndexedGoalsState {
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()

    init(initialStateIndexedGoals: ProjectIndexedGoals,
         inputWriteGoal: SignalProducer<Goal, NoError>,
         inputDeleteGoal: SignalProducer<ProjectID, NoError>,
         outputIndexedGoals: BindingTarget<ProjectIndexedGoals>) {

        indexedGoals = initialStateIndexedGoals

        writeGoal <~ inputWriteGoal
        deleteGoal <~ inputDeleteGoal

        lifetime += outputIndexedGoals <~ indexedGoalsUpdatePipe.output

        sendUpdate()
    }

    // MARK: - State

    private var indexedGoals: ProjectIndexedGoals

    // MARK: - Input

    private lazy var writeGoal = BindingTarget<Goal>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.indexedGoals[$0.projectId] = $0
        self.sendUpdate()
    }

    private lazy var deleteGoal = BindingTarget<ProjectID>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.indexedGoals.removeValue(forKey: $0)
        self.sendUpdate()
    }

    private func sendUpdate() {
        indexedGoalsUpdatePipe.input.send(value: indexedGoals)
    }

    // MARK: - Output

    private let indexedGoalsUpdatePipe = Signal<ProjectIndexedGoals, NoError>.pipe()
}

