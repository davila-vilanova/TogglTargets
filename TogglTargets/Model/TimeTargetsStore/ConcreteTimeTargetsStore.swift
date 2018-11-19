//
//  ConcreteTimeTargetsStore.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

class ConcreteTimeTargetsStore: ProjectIDsProducingTimeTargetsStore {

    private let (lifetime, token) = Lifetime.make()

    private let persistenceProvider: TimeTargetPersistenceProvider
    private let timeTargetWriteScheduler: Scheduler
    private let undoManager: UndoManager

    // MARK: - TimeTarget interface

    /// Holds a function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the time target associated with that
    /// project ID.
    ///
    /// - note: `nil` target values represent a time target that does not exist yet or
    ///         that has been deleted.
    lazy var readTimeTarget: ReadTimeTarget = { projectID in
        self.persistenceProvider.allTimeTargets.producer.map { $0[projectID] }.skipRepeats { $0 == $1 }
    }

    /// Binding target which accepts new (or edited) timeTarget values.
    var writeTimeTarget: BindingTarget<TimeTarget> { return _writeTimeTarget.deoptionalizedBindingTarget }

    /// The value backer for the `writeTimeTarget`binding target.
    private let _writeTimeTarget = MutableProperty<TimeTarget?>(nil)

    /// Binding target which, for each received project ID, removes the timeTarget associated with that project ID.
    var deleteTimeTarget: BindingTarget<ProjectID> { return _deleteTimeTarget.deoptionalizedBindingTarget }

    /// The value backer for the `deleteTimeTarget` binding target.
    private let _deleteTimeTarget = MutableProperty<ProjectID?>(nil)

    // MARK: - Generation of ProjectIDsByTimeTargets

    /// Target that accepts an array of unsorted project IDs that will be matched against the time targets
    /// that this store has knowledge of.
    var projectIDs: BindingTarget<[ProjectID]> { return _projectIDs.deoptionalizedBindingTarget }

    /// The value backer for the `projectIDs` binding target.
    private var _projectIDs = MutableProperty<[ProjectID]?>(nil)

    /// Produces a new `ProjectIDsByTimeTargets` value each time a value is sent to the `projectIDs` target
    /// that contains a different set of unique IDs than the last seen one.
    private lazy var projectIDsByTimeTargetsFullRefresh: SignalProducer<ProjectIDsByTimeTargets, NoError> =
        _projectIDs.producer.skipNil().withLatest(from: persistenceProvider.allTimeTargets)
            .skipRepeats { (old, new) -> Bool in // let through only changes in project IDs, order insensitive
                let oldIds = Set(old.0)
                let newIds = Set(new.0)
                return oldIds == newIds
            }
            .map(ProjectIDsByTimeTargets.init)

    /// Used to connect the output of the current `SingleTimeTargetUpdateComputer`
    /// to `projectIDsByTimeTargetsProducer`.
    private let projectIDsByTimeTargetsLastSingleUpdate =
        MutableProperty<ProjectIDsByTimeTargets.SingleTimeTargetUpdate?>(nil)

    /// Producer of `ProjectIDsByTimeTargets.Update` values that when started emits a
    // `full(ProjectIDsByTimeTargets)` value which can be followed by by full or
    /// incremental updates, corresponding to the `ProjectIDsByTimeTargets` generated
    /// by matching project IDs provided to the `projectIDs` target against the
    /// time targets this store knows about.
    lazy var projectIDsByTimeTargetsProducer: ProjectIDsByTimeTargetsProducer =
        SignalProducer.merge(
            // Send a full value and any full value updates that happen from now on
            projectIDsByTimeTargetsFullRefresh.map (ProjectIDsByTimeTargets.Update.full),
            // Send any updates to a single time target that happen from now on
            projectIDsByTimeTargetsLastSingleUpdate.producer.skipNil()
                .map (ProjectIDsByTimeTargets.Update.singleTimeTarget)
    )

    /// Registers an undo action for each received `TimeTarget` that, if and when invoked, will have the same effect as
    /// sending the received value to `writeTimeTarget`.
    lazy var undoModifyOrDeleteTimeTarget =
        BindingTarget<TimeTarget>(on: timeTargetWriteScheduler,
                                  lifetime: lifetime, // swiftlint:disable:next line_length
                                  action: { [unowned write = _writeTimeTarget, unowned undoManager] timeTargetBeforeEditing in
                                    undoManager.registerUndo(withTarget: write) {
                                        $0 <~ SignalProducer(value: timeTargetBeforeEditing)
                                            .start(on: UIScheduler())
                                    }
        })

    /// Registers an undo action for each received `ProjectID` that, if and when invoked, will have the same effect as
    /// sending the received value to `deleteTimeTarget`.
    lazy var undoCreateTimeTarget =
        BindingTarget<ProjectID>(on: timeTargetWriteScheduler,
                                 lifetime: lifetime,
                                 action: { [unowned delete = _deleteTimeTarget, unowned undoManager] projectId in
                                    undoManager.registerUndo(withTarget: delete,
                                                             handler: {
                                                                $0 <~ SignalProducer(value: projectId)
                                                                    .start(on: UIScheduler()) })
        })

    /// Initializes a ConcreteTimeTargetsStore.
    /// 
    /// - parameters:
    ///   - persistenceProvider: The `TimeTargetPersistenceProvider` used to persist the managed time targets.
    ///   - timeTargetWriteScheduler: The scheduler in which to schedule any time target modifying operations issued
    ///                               by this instance.
    init(persistenceProvider: TimeTargetPersistenceProvider,
         writeTimeTargetsOn timeTargetWriteScheduler: Scheduler,
         undoManager: UndoManager) {
        self.persistenceProvider = persistenceProvider
        self.timeTargetWriteScheduler = timeTargetWriteScheduler
        self.undoManager = undoManager

        let writeTimeTargetProducer = _writeTimeTarget.producer.skipNil()
        let deleteTimeTargetProducer = _deleteTimeTarget.producer.skipNil()

        let timeTargetsPreModification = writeTimeTargetProducer.map { $0.projectId }
            .withLatest(from: persistenceProvider.allTimeTargets).map { $0.1[$0.0] }.skipNil()
        let timeTargetsPreDeletion = deleteTimeTargetProducer.withLatest(from: persistenceProvider.allTimeTargets)
            .map { $0.1[$0.0] }.skipNil()

        undoModifyOrDeleteTimeTarget <~ SignalProducer.merge(timeTargetsPreModification, timeTargetsPreDeletion)

        let projectIdsOfCreatedTimeTargets = writeTimeTargetProducer.map { $0.projectId }
            .withLatest(from: persistenceProvider.allTimeTargets)
            .map { ($0.1[$0.0], $0.0) }.filter { $0.0 == nil }.map { $0.1 }

        undoCreateTimeTarget <~ projectIdsOfCreatedTimeTargets

        let singleTimeTargetUpdateComputer = Property<SingleTimeTargetUpdateComputer?>(
            initial: nil,
            then: projectIDsByTimeTargetsFullRefresh.withLatest(from: persistenceProvider.allTimeTargets)
                .map { [unowned self] (projectIDsByTimeTargetsState, indexedTimeTargetsState) in
                    SingleTimeTargetUpdateComputer(initialStateIndexedTimeTargets: indexedTimeTargetsState,
                                                   initialStateProjectIDsByTimeTargets: projectIDsByTimeTargetsState,
                                                   inputWriteTimeTarget: writeTimeTargetProducer,
                                                   inputDeleteTimeTarget: deleteTimeTargetProducer,
                                                   outputProjectIDsByTimeTargetsUpdate:
                        self.projectIDsByTimeTargetsLastSingleUpdate.deoptionalizedBindingTarget)
            }
        )

        lifetime.observeEnded {
            _ = singleTimeTargetUpdateComputer
        }

        persistenceProvider.persistTimeTarget <~ writeTimeTargetProducer
        persistenceProvider.deleteTimeTarget <~ deleteTimeTargetProducer
    }
}

// MARK: -

/// Generates single time target updates to a `ProjectIDsByTimeTargets` collection based on the received write and
/// delete time target operations.
/// This can process and keep track of single updates only. Whenever a full update is received the current instance
/// of `SingleTimeTargetUpdateComputer` should be discarded and a new one initialized.
private class SingleTimeTargetUpdateComputer {
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler()

    /// Initializes a new instance with the state of an indexed collection of time targets and of a
    /// `ProjectIDsByTimeTargets` collection.
    ///
    /// - parameters:
    ///   - initialStateIndexedTimeTargets: The initial state of the tracked time targets.
    ///   - initialStateProjectIDsByTimeTargets: The initial state of the tracked project IDs by time targets.
    ///   - inputWriteTimeTarget: A producer of `write time target` events whose value is the modified or created time
    ///     target.
    ///   - inputDeleteTimeTarget: A producer of `delete time target` events whose value is the project ID to which the
    ///     deleted time target was associaed.
    ///   - outputProjectIDsByTimeTargetsUpdate: A binding target that will receive the single time target updates that
    ///     this instance will generate to the initial state of the project IDs by time targets.
    init(initialStateIndexedTimeTargets: ProjectIdIndexedTimeTargets,
         initialStateProjectIDsByTimeTargets: ProjectIDsByTimeTargets,
         inputWriteTimeTarget: SignalProducer<TimeTarget, NoError>,
         inputDeleteTimeTarget: SignalProducer<ProjectID, NoError>,
         outputProjectIDsByTimeTargetsUpdate: BindingTarget<ProjectIDsByTimeTargets.SingleTimeTargetUpdate>) {

        indexedTimeTargets = initialStateIndexedTimeTargets
        projectIDsByTimeTargets = initialStateProjectIDsByTimeTargets

        writeTimeTarget <~ inputWriteTimeTarget
        deleteTimeTarget <~ inputDeleteTimeTarget

        lifetime += outputProjectIDsByTimeTargetsUpdate <~ projectIDsByTimeTargetsUpdatePipe.output
    }

    // MARK: - State

    private var indexedTimeTargets: ProjectIdIndexedTimeTargets
    private var projectIDsByTimeTargets: ProjectIDsByTimeTargets

    // MARK: - Input

    private lazy var writeTimeTarget = BindingTarget<TimeTarget>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.computeAndUpdate(timeTarget: $0, projectID: $0.projectId)
    }

    private lazy var deleteTimeTarget = BindingTarget<ProjectID>(on: scheduler, lifetime: lifetime) { [unowned self] in
        self.computeAndUpdate(timeTarget: nil, projectID: $0)
    }

    private func computeAndUpdate(timeTarget: TimeTarget?, projectID: ProjectID) {
        // Compute update
        guard let update = ProjectIDsByTimeTargets.SingleTimeTargetUpdate
            .forTimeTargetChange(involving: timeTarget,
                                 for: projectID,
                                 within: indexedTimeTargets,
                                 affecting: projectIDsByTimeTargets)
            // would return nil only if `projectID` were not included in `projectIDsByTimeTargets`
            else {
                return
        }

        // Update internal state
        indexedTimeTargets[projectID] = timeTarget
        projectIDsByTimeTargets = update.apply(to: projectIDsByTimeTargets)

        // Send update
        projectIDsByTimeTargetsUpdatePipe.input.send(value: update)
    }

    // MARK: - Output

    private let projectIDsByTimeTargetsUpdatePipe =
        Signal<ProjectIDsByTimeTargets.SingleTimeTargetUpdate, NoError>.pipe()
}
