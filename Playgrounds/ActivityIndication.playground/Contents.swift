import AppKit
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

//PlaygroundPage.current.needsIndefiniteExecution = true

fileprivate extension ActivityStatus {
    var isSuccessful: Bool {
        switch self {
        case .succeeded: return true
        default: return false
        }
    }
}


let statuses = MutableProperty([ActivityStatus]())

func canBeCollapsed(_ statuses: [ActivityStatus]) -> Bool {
    guard statuses.count == 2 else {
        return false
    }
    for status in statuses {
        if !status.isSuccessful {
            return false
        }
    }

    return true
}

let action = Action<[ActivityStatus], [ActivityStatus], NoError> {
    guard canBeCollapsed($0) else {
        return SignalProducer.empty
    }
    return SignalProducer(value: [ActivityStatus.succeeded(.retrieveAll)])
}

statuses <~ action.values.logEvents()

action <~ statuses.producer.filter(canBeCollapsed)


