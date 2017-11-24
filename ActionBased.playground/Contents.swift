import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


class TogglAPIAccess2 {
    // MARK: - Exposed inputs

    var apiCredential: BindingTarget<TogglAPICredential> { return _apiCredential.deoptionalizedBindingTarget }


    // MARK: - Backing of inputs

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)


    // MARK: - Derived properties

    private lazy var urlSession: MutableProperty<URLSession?> = {
        let p = MutableProperty<URLSession?>(nil)
        p <~ _apiCredential.producer.skipNil().map(URLSession.init)
        return p
    }()


    // MARK: - Actions that do most of the actual work

    lazy var actionRetrieveProfileFromNetwork =
        Action<(), Profile, APIAccessError>(unwrapping: urlSession) {
            $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }


    // MARK: - Triggers to apply actions when their state changes

//    private func setUpActionStateChangeTriggers() {
//        urlSession.producer.skipNil().startWithValues { _ in  }
//    }

}

let apiAccess = TogglAPIAccess2()

let profile = MutableProperty<Profile?>(nil)
profile <~ apiAccess.actionRetrieveProfileFromNetwork.values.logEvents(identifier: "action.values")
let error = MutableProperty<APIAccessError?>(nil)
error <~ apiAccess.actionRetrieveProfileFromNetwork.errors.logEvents(identifier: "action.errors")

apiAccess.apiCredential <~
    SignalProducer<TogglAPICredential, NoError>(value: TogglAPITokenCredential(apiToken: "8e536ec872a3900a616198ecb3415c03")!)

apiAccess.actionRetrieveProfileFromNetwork.apply().start()

//apiAccess.apiCredential <~
//    SignalProducer<TogglAPICredential, NoError>(value: TogglAPITokenCredential(apiToken: "8e536ec872a3900a616198ecb3415c0")!)

apiAccess.actionRetrieveProfileFromNetwork.apply().startWithResult { print ("result: \($0)") }
