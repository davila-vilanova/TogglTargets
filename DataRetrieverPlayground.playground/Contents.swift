import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

let apiToken = MutableProperty("8e536ec872a3900a616198ecb3415c03")
let credential = apiToken.map { token -> TogglAPICredential? in TogglAPITokenCredential(apiToken: token) }

let start =     DayComponents(year: 2017, month: 12, day: 1)
let yesterday = DayComponents(year: 2017, month: 12, day: 12)
let today =     DayComponents(year: 2017, month: 12, day: 13)
let end =       DayComponents(year: 2017, month: 12, day: 31)

let reportPeriod = TwoPartTimeReportPeriod(full: Period(start: start, end: end),
                                           previousToToday: Period(start: start, end: yesterday),
                                           today: Period(start: today, end: today))

let dataRetriever = TogglAPIDataRetriever(retrieveProfileNetworkAction: makeRetrieveProfileNetworkAction(),
                                          retrieveProfileCacheAction: makeRetrieveProfileCacheAction(),
                                          storeProfileCacheAction: makeStoreProfileCacheAction(),
                                          retrieveProjectsNetworkAction: makeRetrieveProjectsNetworkAction(),
                                          retrieveReportsNetworkAction: makeRetrieveReportsNetworkAction(),
                                          retrieveRunningEntryNetworkAction: makeRetrieveRunningEntryNetworkAction())
let lastError = Property<APIAccessError?>(initial: nil, then: dataRetriever.errors.logEvents(identifier: "errors"))

class InertGoalsStore: ProjectIDsByGoalsProducingGoalsStore {
    var readGoalAction = ReadGoalAction { _ in SignalProducer(value: Property(value: nil)) }
    var writeGoalAction = WriteGoalAction { _ in SignalProducer.empty }
    var deleteGoalAction = DeleteGoalAction { _ in SignalProducer.empty }
    var projectIDs: BindingTarget<[ProjectID]> { return _projectIDs.bindingTarget }
    var fetchProjectIDsByGoalsAction = FetchProjectIDsByGoalsAction {
        return SignalProducer(value: ProjectIDsByGoals.Update.full(ProjectIDsByGoals.empty))
    }
    let _projectIDs = MutableProperty([ProjectID]())
}


let modelCoordinator = ModelCoordinator(togglDataRetriever: dataRetriever,
                                        goalsStore: InertGoalsStore(),
                                        currentDateGenerator: CurrentDateGenerator.shared)

modelCoordinator.apiCredential <~ credential
modelCoordinator.twoPartReportPeriod <~ SignalProducer(value: reportPeriod)

//dataRetriever.projects.producer.startWithValues { print("projects: \(String.init(describing: $0))") }
modelCoordinator.readReportAction.apply(7866454).materialize().startWithValues { print("report: \(String.init(describing: $0))") }
