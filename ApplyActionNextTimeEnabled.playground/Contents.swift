//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift

extension Action where Input == () {
    func applyNextTimeEnabled() {
        self.isEnabled.producer
            .filter { $0 } // only trues
            .take(first: 1) // only first true
            .map { _ in () }
            .startWithValues { [unowned self] in
                self.apply().start()
        }
    }
}

let state = MutableProperty<Int?>(nil)

let action = Action<(), Double, NoError>(unwrapping: state) {
    return SignalProducer(value: Double($0))
}

let result = MutableProperty<Double?>(nil)
let enabled = MutableProperty<Bool>(false)
result <~ action.values.logEvents(identifier: "value", events: [.value])
enabled <~ action.isEnabled.producer.logEvents(identifier: "isEnabled", events: [.value])

let enabledP = Property(capturing: enabled)
//action.applyNextTimeEnabled()
enabledP.producer
    .filter { $0 }
    .take(first: 1)
    .map { _ in () }
    .startWithValues {
        action.apply().start()
}

state.value = 1
//action.apply().start()
result.value
