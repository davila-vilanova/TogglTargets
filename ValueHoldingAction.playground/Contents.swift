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
// + Apply does not require inputs and does not produce output
