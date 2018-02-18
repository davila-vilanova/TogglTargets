import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

//let previous: [ActivityStatus] = [.succeeded(.syncProfile), .executing(.syncProjects), .executing(.syncReports)]
//let current: [ActivityStatus] = [.succeeded(.syncProfile), .succeeded(.syncProjects), .executing(.syncReports)]


let state = MutableProperty(0)
var output = state.signal
    .combinePrevious(0)

let semaphore = DispatchSemaphore(value: 0)

var value: (Int, Int) = (0, 0)
output.take(first: 1).on(value: { value = $0; semaphore.signal() })
state.value = 1
semaphore.wait()
value.0
value.1

output.take(first: 1).on(value: { value = $0; semaphore.signal() })
state.value = 2
semaphore.wait()
value.0
value.1

