import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

let formatter = DateFormatter()
formatter.dateStyle = .none
formatter.timeStyle = .medium

formatter.string(from: Date())
