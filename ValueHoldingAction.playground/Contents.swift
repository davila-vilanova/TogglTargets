//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


// Action substitute:
// + Has input
// + Holds latest output in .values
// + Runs serially
// + Has .errors property. Errors are producer errors, not action errors. Cannot be disabled
// + Apply does not require inputs and does not produce output. Apply is used just to force a retry?

let input: SignalProducer<URLSession, NoError> =
    SignalProducer(value: URLSession(togglAPICredential: TogglAPITokenCredential(apiToken: "8e536ec872a3900a616198ecb3415c03")!))

let outputValueBacker = MutableProperty<Profile?>(nil)
let outputValue: SignalProducer<Profile, NoError> = outputValueBacker.producer.skipNil()

let (outputError, outputErrorObserver) = Signal<APIAccessError, NoError>.pipe()

let queueScheduler = QueueScheduler()

func retryIf() {

}

func execute() {
    input.take(first: 1)
        .start(on: queueScheduler)
        .startWithValues { execute(input: $0) }
}

// private
func execute(input: URLSession) {
    let oneRetrievalAttempt: SignalProducer<Profile, ActionError<APIAccessError>> =
        actionRetrieveProfile.apply(input)

    let (oneRetrievalAttemptSignal, oneRetrievalAttemptObserver) = Signal<Profile, ActionError<APIAccessError>>.pipe()
    oneRetrievalAttempt.start(oneRetrievalAttemptObserver)

    outputValueBacker <~ oneRetrievalAttemptSignal.materialize().filterMap { $0.value }
    oneRetrievalAttemptSignal
        .materialize()
        .filterMap { $0.error }
        .filterMap { $0.producerError }
        .on(value: { outputErrorObserver.send(value: $0) })
}

extension ActionError {
    var producerError: Error? {
        if case let .producerFailed(error) = self {
            return error
        } else {
            return nil
        }
    }
}
