import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

class ModelCoordinator2 {

    internal lazy var profileAction = Action<(), Profile, APIAccessError> { [unowned self] in
        let cached = self.cache.retrieveCachedProfile()
        let (cachedSignal, cachedObserver) = Signal<(result: Profile?, mustRefresh: Bool), NoError>.pipe()

        cached.startWithSignal({ (signal, disposable) -> Void in
            signal.observe(cachedObserver)
            // TODO: disposable
        })

        let cachedProfile = cachedSignal.map { $0.result }.skipNil()
        let mustRefresh = cachedSignal.logEvents(identifier: "cachedSignal").map { $0.mustRefresh }
        //  |   cached?  |   mustRefresh?    |
        //  |   no       |      yes          |
        //  |   yes      |      no           |
        //  |   yes      |      yes          |
        let refreshedProfile: SignalProducer<Profile, APIAccessError> =
            mustRefresh.producer.filter { $0 }//.logEvents(identifier: "mustRefresh")
            .combineLatest(with: self.urlSession)
            .map { (_, session) in actionRetrieveProfile.apply(session).mapError(assertProducerError) }
            .take(first: 1).flatten(.latest)

        return SignalProducer.merge(cachedProfile.producer.promoteError(APIAccessError.self), refreshedProfile)
    }

    private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)
    private lazy var urlSession = _apiCredential.producer.skipNil().map(URLSession.init)

    let cache = Cache()
}

class Cache {
    func retrieveCachedProfile() -> SignalProducer<(result: Profile?, mustRefresh: Bool), NoError> {
        return SignalProducer(value: (nil, true))
    }
}

let mc = ModelCoordinator2()

let profileHolder = MutableProperty<Profile?>(nil)
profileHolder <~ mc.profileAction.values.logEvents()

mc.profileAction.apply().start()
print ("start")
