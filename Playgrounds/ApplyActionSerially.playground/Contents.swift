import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

struct SuchBadError: Error, CustomDebugStringConvertible {
    var debugDescription = "<[Oh, snap!]>"

}

print("a")

let action = Action<String, String, SuchBadError> { input in
    Thread.sleep(forTimeInterval: 0.4)
    if input == "fourth" {
        return SignalProducer(error: SuchBadError())
    } else {
        return SignalProducer(value: "\(input) + action")
    }
}

let valuesSink = MutableProperty<String>("")
valuesSink <~ action.values.logEvents(identifier: "value", events: [.value])

let errorsSink = MutableProperty(SuchBadError())
errorsSink <~ action.errors.logEvents(identifier: "error", events: [.value])

let busySink = MutableProperty<()>(())
busySink <~ action.disabledErrors.logEvents(identifier: "disabled", events: [.value])


for value in ["first", "second", "third", "fourth", "fifth"] {
    action.applySerially(value).start()
}

print("b")

class SerialExecutionAction<Input, Output, Error: Swift.Error> {
    let wrappedAction: Action<Input, Output, Error>

    init(wrapping action: Action<Input, Output, Error>) {
        wrappedAction = action
    }

//    func apply(_ input: Input) -> SignalProducer<Output, Error> {
//        wrappedAction.isEnabled.producer.filter { $0 }.startWithValues { _ in
//            let p: SignalProducer<Output, ActionError<Error>> = wrappedAction.apply(input)
//        }
//    }
}
