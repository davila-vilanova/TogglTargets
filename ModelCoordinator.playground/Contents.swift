import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


class NonPersistentGoalsStore: GoalsStore {
    lazy var allGoals = Property(_allGoals)
    private let _allGoals = MutableProperty([ProjectID: Goal]())

    lazy var readGoalAction = Action<ProjectID, Goal?, NoError> { [unowned self] projectId in
        self._allGoals.producer.map { $0[projectId] }.skipRepeats { $0 == $1 }
    }
    lazy var writeGoalAction = Action<Goal, Void, NoError> { [unowned self] goal in
        self._allGoals.value[goal.projectId] = goal
        return SignalProducer.empty
    }
    lazy var deleteGoalAction = Action<ProjectID, Void, NoError> { [unowned self] projectId in
        self._allGoals.value[projectId] = nil
        return SignalProducer.empty
    }
}

let retrieveProfileNetworkAction = makeRetrieveProfileNetworkAction()

let modelCoordinator = 
    ModelCoordinator(retrieveProfileNetworkAction: retrieveProfileNetworkAction,
                     retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                     storeProfileCacheAction: makeStoreProfileCacheAction(),
                     retrieveProjectsNetworkAction: makeRetrieveProjectsNetworkAction(),
                     retrieveReportsNetworkAction: makeRetrieveReportsNetworkAction(),
                     retrieveRunningEntryNetworkAction: makeRetrieveRunningEntryNetworkAction(),
                     goalsStore: NonPersistentGoalsStore())

let profile = MutableProperty<Profile?>(nil)
let projects = MutableProperty<IndexedProjects?>(nil)
let error = MutableProperty<APIAccessError?>(nil)

profile <~ modelCoordinator.profile.producer.logEvents(identifier: "modelCoordinator.profile", events: [.value])
error <~ retrieveProfileNetworkAction.errors.logEvents(identifier: "error")

let d0 = retrieveProfileNetworkAction.disabledErrors.on(value: {
    print("!!!! retrieveProfileNetworkAction.disabledError: \($0)")
})

projects <~ modelCoordinator.projects.producer.logEvents(identifier: "modelCoordinator.projects")

let apiToken = MutableProperty("8e536ec872a3900a616198ecb3415c03")
let credential = apiToken.map { token -> TogglAPICredential? in TogglAPITokenCredential(apiToken: token) }


modelCoordinator.apiCredential <~ credential

//apiToken.value = "8e536ec872a3900a616198ecb3415c02"

print("going for it")

