import Foundation
import Result
import ReactiveSwift
//@testable import TogglGoals_MacOS
import PlaygroundSupport

extension SignalProducerConvertible where Value: OptionalProtocol, Error == NoError  {
    func latestOutput<T>(_ selector: @escaping (Value.Wrapped) -> SignalProducer<T, NoError>) -> SignalProducer<T, NoError> {
        return producer.skipNil().map(selector).flatten(.latest)
    }
}

extension SignalProducerConvertible where Error == NoError {
    func bindOnlyToLatest(_ bindingTargetProducer: SignalProducer<BindingTarget<Value>, NoError>) -> Disposable {
        let disposable = SerialDisposable()
        bindingTargetProducer.startWithValues { target in
            disposable.inner = target <~ self.producer
        }
        return disposable
    }
}

let targets = MutableProperty<BindingTarget<Int>?>(nil)
let source = MutableProperty(0)

source.bindOnlyToLatest(targets.producer.skipNil())


let p1 = MutableProperty<Int>(-100)
let p2 = MutableProperty<Int>(-200)

let (globalLifetime, globalToken) = Lifetime.make()

globalLifetime += p1.producer.startWithValues { print("[1] <- \($0)") }
globalLifetime += p2.producer.startWithValues { print("[2] <- \($0)") }

targets.value = p1.bindingTarget

source.value = 1
source.value = 2
source.value = 3

targets.value = p2.bindingTarget

source.value = 4
source.value = 5
source.value = 6



class A {
    let intEmitter = MutableProperty(0)
    var b: B? {
        didSet {
            if let b = b {
                b.interface <~ SignalProducer(value: intEmitter.producer)
            }
        }
    }
}

class B {
    typealias Interface = SignalProducer<Int, NoError>
    let interface = MutableProperty<Interface?>(nil)
    let stringReceiver = MutableProperty<String>("")

    var c: C? {
        didSet {
            if let c = c {
                c.interface <~ SignalProducer(
                    value: (interface.latestOutput { $0 },
                            stringReceiver.bindingTarget))
            }
        }
    }
}

class C {
    typealias Interface = (
        SignalProducer<Int, NoError>,
        BindingTarget<String>)

    let interface = MutableProperty<Interface?>(nil)

    let (lifetime, token) = Lifetime.make()
    init() {
        let intReceiver = MutableProperty<Int?>(nil)
        let stringEmitter = MutableProperty<String?>(nil)
        lifetime.observeEnded {
            _ = intReceiver
            _ = stringEmitter
        }

        lifetime += stringEmitter <~ intReceiver.producer.skipNil().map { "received int: \($0)" }

        // Connnect to latest interface: intput
        lifetime += intReceiver <~ interface.latestOutput { $0.0 }

        // Connect to latest interface: output
        lifetime += stringEmitter.producer.skipNil().bindOnlyToLatest(interface.producer.skipNil().map { $0.1 })
    }
}

let globalIntEmitter1 = MutableProperty(1)
let globalIntEmitter2 = MutableProperty(2)
let globalStringReceiver = MutableProperty<String>("")

let a1 = A(); let a2 = A(); let b = B(); let c = C()
globalLifetime += a1.intEmitter <~ globalIntEmitter1
globalLifetime += a2.intEmitter <~ globalIntEmitter2

globalLifetime += globalStringReceiver <~ b.stringReceiver.producer.logEvents(identifier: "globalStringReceiver <~ b.stringReceiver", events: [.value])

b.c = c
a1.b = b

globalIntEmitter2.value = -8
globalIntEmitter2.value = -6

globalIntEmitter1.value = 3
globalIntEmitter2.value = -4
globalIntEmitter1.value = 5
globalIntEmitter2.value = -2
globalIntEmitter1.value = 7

a2.b = b

globalIntEmitter1.value = 9

globalIntEmitter2.value = 4
globalIntEmitter2.value = 6
globalIntEmitter2.value = 8

