import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

//let action1 = Action<String, String, NoError> {
//    return SignalProducer(value: "\($0)+action1")
//}
//let action2 = Action<String, String, NoError> {
//    return SignalProducer(value: "\($0)+action2")
//}
//
//let sender = SignalProducer(value: "original")
//let receiver = MutableProperty<String>("")
//receiver <~ action2.values.logEvents(identifier: "receiver")
//
//action2 <~ action1.values
//action1 <~ sender


let apiAccess = TogglAPIAccess()
let apiToken = "8e536ec872a3900a616198ecb3415c03"
apiAccess.apiCredential <~
    SignalProducer<TogglAPICredential, NoError>(value: TogglAPITokenCredential(apiToken: apiToken)!)

let profile = MutableProperty<Profile?>(nil)
let projects = MutableProperty<IndexedProjects?>(nil)
let error = MutableProperty<APIAccessError?>(nil)

profile <~ apiAccess.actionRetrieveProfile.values.logEvents(identifier: "actionRetrieveProfile.values")
projects <~ apiAccess.actionRetrieveProjects.values.logEvents(identifier: "actionRetrieveProjects.values")

error <~ Signal.merge(apiAccess.actionRetrieveProfile.errors, apiAccess.actionRetrieveProjects.errors)
    .logEvents(identifier: "errors")


apiAccess.actionRetrieveProfile.apply(apiAccess.urlSession.value!).startWithResult { (result) in
    print("result: \(result)")
}



//print("going for it 2")

