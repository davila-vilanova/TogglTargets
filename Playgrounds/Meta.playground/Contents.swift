import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

typealias F = ((Int)->Int)

let impl = { (a: Int) -> Int in a + 1 }

let f = MutableProperty<F>(impl)
let x = MutableProperty(1)

let (lifetime, token) = Lifetime.make()
let y = BindingTarget<Int>(lifetime: lifetime) {
    print ("y=\($0)")
}

y <~ SignalProducer.combineLatest(f, x).map { f, x in f(x) }

f.value = { $0 * 8 }
x.value = 3

let g = MutableProperty<(F, Int)>((impl, 7))

