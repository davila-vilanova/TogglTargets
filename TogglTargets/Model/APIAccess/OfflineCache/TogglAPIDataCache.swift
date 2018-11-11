//
//  TogglAPIDataCache.swift
//  TogglTargets
//
//  Created by David Dávila on 29.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

/// An `Action` that upon application produces the latest cached user profile or a nil value if no cached profile is
/// available.
typealias RetrieveProfileCacheAction = Action<(), Profile?, NoError>

/// An `Action` that when applied produces the latest cached collection of user projects or a nil value if no cached
/// projects are available.
typealias RetrieveProjectsCacheAction = Action<(), IndexedProjects?, NoError>

/// Manages a `TogglAPIDataPersistenceProvider` and provides binding targets and retrieval actions to locally store
/// and retrieve the user's Toggl profile and projects.
internal class TogglAPIDataCache {
    private let persistenceProvider: TogglAPIDataPersistenceProvider
    private let scheduler: QueueScheduler
    private let (lifetime, token) = Lifetime.make()

    internal let retrieveProfile: RetrieveProfileCacheAction
    internal let retrieveProjects: RetrieveProjectsCacheAction
    internal let storeProfile: BindingTarget<Profile?>
    internal let storeProjects: BindingTarget<IndexedProjects?>

    init(persistenceProvider: TogglAPIDataPersistenceProvider) {
        self.persistenceProvider = persistenceProvider

        let scheduler = QueueScheduler()
        self.scheduler = scheduler

        retrieveProfile = RetrieveProfileCacheAction {
            return SignalProducer<Profile?, NoError> { [unowned scheduler] observer, lifetime in
                lifetime += scheduler.schedule {
                    observer.send(value: persistenceProvider.retrieveProfile())
                    observer.sendCompleted()
                }
            }
        }

        retrieveProjects = RetrieveProjectsCacheAction {
            return SignalProducer<[Project]?, NoError> { [unowned scheduler] observer, lifetime in
                lifetime += scheduler.schedule {
                    observer.send(value: persistenceProvider.retrieveProjects())
                    observer.sendCompleted()
                }
                }.map { (projects: [Project]?) -> IndexedProjects? in
                    guard let projects = projects else {
                        return nil
                    }
                    return projects.reduce(IndexedProjects(), { (indexed, project) -> IndexedProjects in
                        return indexed.merging([project.id: project], uniquingKeysWith: { (_, new) -> Project in new })
                    })
            }
        }

        storeProfile = BindingTarget(on: scheduler, lifetime: lifetime) {
            if let profile = $0 {
                scheduler.schedule { persistenceProvider.persist(profile: profile) }
            } else {
                scheduler.schedule { persistenceProvider.deleteProfile() }
            }
        }

        storeProjects = BindingTarget(on: scheduler, lifetime: lifetime) {
            if let projects = $0 {
                scheduler.schedule { persistenceProvider.persist(projects: [Project](projects.values)) }
            } else {
                scheduler.schedule { persistenceProvider.deleteProjects() }
            }
        }
    }
}
