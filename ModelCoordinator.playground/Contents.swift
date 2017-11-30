import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


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

profile <~ modelCoordinator.profile.producer.logEvents(identifier: "modelCoordinator.profile", events: [.value])
error <~ modelCoordinator.retrieveProfileNetworkAction.errors.logEvents(identifier: "error")

let d0 = modelCoordinator.retrieveProfileNetworkAction.disabledErrors.on(value: {
    print("!!!! retrieveProfileNetworkAction.disabledError: \($0)")
})

//projects <~ modelCoordinator.projects.producer.logEvents(identifier: "modelCoordinator.projects")

let apiToken = MutableProperty("8e536ec872a3900a616198ecb3415c03")
let credential = apiToken.map { token -> TogglAPICredential? in TogglAPITokenCredential(apiToken: token) }


modelCoordinator.apiCredential <~ credential

apiToken.value = "8e536ec872a3900a616198ecb3415c02"

print("going for it")

