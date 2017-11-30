//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true
let apiToken = MutableProperty("rewq")
let credential = apiToken.map { token -> TogglAPICredential? in TogglAPITokenCredential(apiToken: token) }
let session = credential.map(URLSession.init)
let profile = MutableProperty<Profile?>(nil)



/// A wrapper for an action that should not miss the most recent value sent through its input
/// even if the action is busy executing work based on a previous input value when a new input value arrives.
protocol LatestInputObservingActionWrapper: BindingTargetProvider {
    associatedtype Input
    associatedtype Output
    associatedtype Error: Swift.Error

    var wrappedAction: Action<Input, Output, Error> { get }

    /// This is the lifetime of the wrapper, not of the wrapped action
    var lifetime: Lifetime { get }

    /// Target which accepts input values for the wrapped action
    var bindingTarget: BindingTarget<Input> { get }
}

/// A wrapper for an action that should only care about the latest value sent through its input and cancels any
/// ongoing work when a new input value arrives, started a new unit of work based on that value.
class EasilyDistractableLatestInputObservingActionWrapper<Input, Output, Error: Swift.Error>: LatestInputObservingActionWrapper {

    public let wrappedAction: Action<Input, Output, Error>

    public let lifetime: Lifetime
    private let deinitToken: Lifetime.Token

    /// Used to keep a handle to cancel the latest unit of work
    /// if a new value arrives before the previous work finishes
    private var currentWorkDisposable: Disposable?

    init(wrapping action: Action<Input, Output, Error>) {
        wrappedAction = action
        (lifetime, deinitToken) = Lifetime.make()
    }

    /// Target which accepts input values for the wrapped action
    public var bindingTarget: BindingTarget<Input> {
        return BindingTarget(lifetime: lifetime) { [unowned self] (input: Input) in // TODO: unowned or weak? ramifications
            if let disposable = self.currentWorkDisposable, !disposable.isDisposed {
                disposable.dispose()
            }
            self.currentWorkDisposable = self.wrappedAction.apply(input).start()
        }
    }
}

/// A wrapper for an action that throttles its input while it's performing work, so that when it finishes executing
/// it will attempt to issue a unit of work corresponding to the latest input received while it was busy.
class ThrottlingLatestInputObservingActionWrapper<Input, Output, Error: Swift.Error>: LatestInputObservingActionWrapper {

    public let wrappedAction: Action<Input, Output, Error>

    public let lifetime: Lifetime
    private let deinitToken: Lifetime.Token

    private let (inputSignal, inputObserver) = Signal<Input, NoError>.pipe()
    private let scheduler = QueueScheduler()

    init(wrapping action: Action<Input, Output, Error>) {
        wrappedAction = action
        (lifetime, deinitToken) = Lifetime.make()

        action <~ inputSignal.throttle(while: action.isExecuting, on: scheduler)
    }

    public var bindingTarget: BindingTarget<Input> {
        return BindingTarget(lifetime: lifetime) { [unowned self] (input: Input) in
            self.inputObserver.send(value: input)
        }
    }
}

let retrieveProfile = ThrottlingLatestInputObservingActionWrapper(wrapping: makeRetrieveProfileNetworkAction())
profile <~ retrieveProfile.wrappedAction.values.logEvents()
retrieveProfile <~ session
apiToken.value = "8e536ec872a3900a616198ecb3415c03"

profile.value
