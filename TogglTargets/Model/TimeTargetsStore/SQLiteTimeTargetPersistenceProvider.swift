//
//  SQLiteTimeTargetPersistenceProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import SQLite
import ReactiveSwift

/// A `TimeTargetPersistenceProvider` backed by a SQLite database.
class SQLiteTimeTargetPersistenceProvider: TimeTargetPersistenceProvider {
    /// The database connection used to store and retrieve time targets.
    private let dbConnection: Connection

    private let timeTargetWriteScheduler: Scheduler

    // MARK: - Table and expression entities

    private let timeTargetsTable = Table("time_target")
    private let idExpression = Expression<Int64>("id")
    private let projectIdExpression = Expression<ProjectID>("project_id")
    private let hoursTargetExpression = Expression<Int>("hours")
    private let workWeekdaysExpression = Expression<WeekdaySelection>("work_weekdays")

    // MARK: -

    private let (lifetime, token) = Lifetime.make()
    private lazy var scheduler = QueueScheduler()

    private let _persistTimeTarget = MutableProperty<TimeTarget?>(nil)

    /// Persists the provided time target into the database synchronously.
    var persistTimeTarget: BindingTarget<TimeTarget> { return _persistTimeTarget.deoptionalizedBindingTarget }

    private let _deleteTimeTarget = MutableProperty<ProjectID?>(nil)

    /// Deletes synchronously from the database the time target corresponding to the
    /// provided project ID.
    var deleteTimeTarget: BindingTarget<ProjectID> { return _deleteTimeTarget.deoptionalizedBindingTarget }

    lazy var allTimeTargets = MutableProperty<ProjectIdIndexedTimeTargets>(retrieveAllTimeTargets())

    /// Retrieves all time targets from the database
    private func retrieveAllTimeTargets() -> ProjectIdIndexedTimeTargets {
        var retrievedTimeTargets = ProjectIdIndexedTimeTargets()

        func extractWeekdaySelection(from row: Row) -> WeekdaySelection {
            do {
                return try row.get(workWeekdaysExpression) // [1]
            } catch let error {
                // An error is utterly not expected. Output it to the console and crash if assertions are enabled.
                print("Cannot extract week day selection from row - error: \(error)")
                assert(false)
                return WeekdaySelection.empty
            }
        }

        do {
            let retrievedRows = try dbConnection.prepare(timeTargetsTable)
            for retrievedRow in retrievedRows {
                let projectIdValue = retrievedRow[projectIdExpression]
                let hoursTargetValue = retrievedRow[hoursTargetExpression]
                let workWeekdaysValue = extractWeekdaySelection(from: retrievedRow)
                let timeTarget = TimeTarget(for: projectIdValue,
                                            hoursTarget: hoursTargetValue,
                                            workWeekdays: workWeekdaysValue)
                retrievedTimeTargets[projectIdValue] = timeTarget
            }
        } catch let error {
            print("Cannot retrieve time targets - SQLite threw an error: \(error)")
        }

        return retrievedTimeTargets
        // [1] Can't use subscripts with custom types.
        // https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#custom-type-caveats
        // (f3da195)
    }

    /// Initialize an instance that will read and write its database in the provided base directory.
    /// If no database file exists under the provided directory it will create one.
    /// Returns `nil` if the database file cannot be opened and cannot be created.
    ///
    /// - parameters:
    ///   - baseDirectory: The `URL` of the directory from which to read and to which to write
    ///                    the database used by this instance.
    ///   - timeTargetWriteScheduler: The scheduler in which to schedule any time target writing operations
    ///                               issued by this instance.
    init?(baseDirectory: URL?, writeTimeTargetsOn timeTargetWriteScheduler: Scheduler) {
        do {
            let databaseURL = URL(fileURLWithPath: "timetargetsdb.sqlite3", relativeTo: baseDirectory)
            dbConnection = try Connection(databaseURL.absoluteString)
        } catch {
            return nil
        }
        self.timeTargetWriteScheduler = timeTargetWriteScheduler

        ensureSchemaCreated()

        let persistProducer = _persistTimeTarget.producer.skipNil().on(value: { [unowned self] timeTarget in
            do {
                try self.dbConnection
                    .run(self.timeTargetsTable.insert(or: .replace,
                                                      self.projectIdExpression <- timeTarget.projectId,
                                                      self.hoursTargetExpression <- timeTarget.hoursTarget,
                                                      self.workWeekdaysExpression <- timeTarget.workWeekdays))
            } catch let error {
                print("Cannot persist time targets - SQLite threw an error: \(error)")
                assert(false)
            }
            // TODO: consider synchronizing periodically instead of writing immediately
        }).start(on: timeTargetWriteScheduler)

        let deleteProducer = _deleteTimeTarget.producer.skipNil().on(value: { [unowned self] projectId in
            let query = self.timeTargetsTable.filter(self.projectIdExpression == projectId)
            do {
                try self.dbConnection.run(query.delete())
            } catch let error {
                print("Cannot delete time target - SQLite threw an error: \(error)")
                assert(false)
            }
        }).start(on: timeTargetWriteScheduler)

        allTimeTargets <~ persistProducer.withLatest(from: allTimeTargets).map {
            $1.updatingValue($0, forKey: $0.projectId)
        }

        allTimeTargets <~ deleteProducer.withLatest(from: allTimeTargets).map {
            $1.updatingValue(nil, forKey: $0)
        }
    }

    /// Creates the underlying database schema if not already created.
    private func ensureSchemaCreated() {
        do {
            try dbConnection.run(timeTargetsTable.create(ifNotExists: true) { tableBuilder in
                tableBuilder.column(idExpression, primaryKey: .autoincrement)
                tableBuilder.column(projectIdExpression, unique: true)
                tableBuilder.column(hoursTargetExpression)
                tableBuilder.column(workWeekdaysExpression)
            })
        } catch let error {
            print("\(#function) - SQLite threw an error: \(error)")
            assert(false)
        }
    }
}
