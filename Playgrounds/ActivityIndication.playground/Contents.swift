import AppKit
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

//PlaygroundPage.current.needsIndefiniteExecution = true


let a = [0, 1, 2, 3, 4, 5]
let s = a.drop(while: { ($0 % 2) != 0 })

s
a
