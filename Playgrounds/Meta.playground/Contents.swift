import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

fileprivate extension ActivityStatus {
    func representedBySameController(as anotherStatus: ActivityStatus) -> Bool {
        return isExecuting != anotherStatus.isExecuting ||
            isSuccessful != anotherStatus.isSuccessful ||
            isError != anotherStatus.isError
    }
}
let a = ActivityStatus.executing(.syncProfile)
let b = ActivityStatus.executing(.syncReports)

a.representedBySameController(as: b)
