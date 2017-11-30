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

// Wraps an action and ensures that when an input value is sent to its binding target, if the action is executing,
// the work that it is doing is cancelled and a new item of work is started for the value that just came in
class SelfCancellingAction<Input, Output, Error: Swift.Error>: BindingTargetProvider {
    let wrappedAction: Action<Input, Output, Error>
    public var events: Signal<Signal<Output, Error>.Event, NoError> { return wrappedAction.events }
    public var values: Signal<Output, NoError> { return wrappedAction.values }
    public var errors: Signal<Error, NoError> { return wrappedAction.errors }
    public var disabledErrors: Signal<(), NoError> { return wrappedAction.disabledErrors }
    public var completed: Signal<(), NoError> { return wrappedAction.completed }
    public var isExecuting: Property<Bool> { return wrappedAction.isExecuting }
    public var isEnabled: Property<Bool> { return wrappedAction.isEnabled }


    var currentWorkDisposable: Disposable?

    public let lifetime: Lifetime // TODO: how lifetime relates to wrappedAction's lifetime
    private let deinitToken: Lifetime.Token

    init(wrapping action: Action<Input, Output, Error>) {
        wrappedAction = action
        (lifetime, deinitToken) = Lifetime.make()
    }

    public var bindingTarget: BindingTarget<Input> {
        return BindingTarget(lifetime: lifetime) { [unowned self] (input: Input) in // TODO: unowned or weak? ramifications
            if let disposable = self.currentWorkDisposable, !disposable.isDisposed {
                disposable.dispose()
            }
            self.currentWorkDisposable = self.wrappedAction.apply(input).start()
        }
    }
}

let selfCancellingRetrieveProfileAction = SelfCancellingAction(wrapping: makeRetrieveProfileNetworkAction())
profile <~ selfCancellingRetrieveProfileAction.values.logEvents()
selfCancellingRetrieveProfileAction <~ session
apiToken.value = "8e536ec872a3900a616198ecb3415c03"

profile.value
