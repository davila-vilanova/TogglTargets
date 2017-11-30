import Foundation
import Result
import ReactiveSwift

let action1 = Action<String, String, NoError> {
    return SignalProducer(value: "\($0)+action1")
}
let action2 = Action<String, String, NoError> {
    return SignalProducer(value: "\($0)+action2")
}

let sender = SignalProducer(value: "original")
let receiver = MutableProperty<String>("")
receiver <~ action2.values.logEvents(identifier: "receiver")

action2 <~ action1.values
action1 <~ sender
