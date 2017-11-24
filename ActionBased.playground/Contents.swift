import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa
@testable import TogglGoals_MacOS
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

class ModelCoordinator2 {

    internal lazy var profileAction = Action<(), Profile, APIAccessError> { [unowned self] in
        let (cachedSignal, cachedObserver) = Signal<(result: Profile?, mustRefresh: Bool), ActionError<NoError>>.pipe()
        let cached = self.cache.retrieveCachedProfileAction.apply(0)
        cached.logEvents(identifier: "cached").start(cachedObserver)
        
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
    let retrieveCachedProfileAction = Action<Int64, (result: Profile?, mustRefresh: Bool), NoError> { _ in
        return SignalProducer(value: (nil, true))
    }
}

let mc = ModelCoordinator2()

let profileHolder = MutableProperty<Profile?>(nil)
profileHolder <~ mc.profileAction.values.logEvents()

mc.profileAction.apply().start()
print ("start")
