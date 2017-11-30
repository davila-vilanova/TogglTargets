//
//  AppDelegate.swift
//  SendLockTrip
//
//  Created by David Dávila on 29.11.17.
//  Copyright © 2017 davi.la. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

class DummyGoalsStore: GoalsStore {
    let allGoals = Property(value: [ProjectID: Goal]())
    private let (lifetime, token) = Lifetime.make()
    private lazy var dummyTarget = BindingTarget<Goal?>(lifetime: lifetime) { _ in }

    func goalProperty(for projectId: ProjectID) -> Property<Goal?> {
        return Property(value: nil)
    }

    func goalBindingTarget(for projectId: ProjectID) -> BindingTarget<Goal?> {
        return dummyTarget
    }

    func goalExists(for projectId: ProjectID) -> Bool {
        return false
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let modelCoordinator =
        ModelCoordinator(retrieveProfileNetworkAction: makeRetrieveProfileNetworkAction(),
                         retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                         storeProfileCacheAction: makeStoreProfileCacheAction(),
                         retrieveProjectsNetworkAction: makeRetrieveProjectsNetworkAction(),
                         retrieveReportsNetworkAction: makeRetrieveReportsNetworkAction(),
                         retrieveRunningEntryNetworkAction: makeRetrieveRunningEntryNetworkAction(),
                         goalsStore: DummyGoalsStore())

    let profile = MutableProperty<Profile?>(nil)
    let projects = MutableProperty<IndexedProjects?>(nil)
    let error = MutableProperty<APIAccessError?>(nil)

    let apiToken = MutableProperty("8e536ec872a3900a616198ecb3415c03")
    lazy var credential = apiToken.map { TogglAPITokenCredential(apiToken: $0) as TogglAPICredential? }

    lazy var disabledErrors = MutableProperty<()>(())


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        profile <~ modelCoordinator.profile.producer.logEvents(identifier: "modelCoordinator.profile", events: [.value])
        error <~ modelCoordinator.retrieveProfileNetworkAction.errors.logEvents(identifier: "error")

        disabledErrors <~ modelCoordinator.retrieveProfileNetworkAction.disabledErrors.logEvents(identifier: "disabledError")
        modelCoordinator.apiCredential <~ credential

        apiToken.value = "8e536ec872a3900a616198ecb3415c02"
    }
}

