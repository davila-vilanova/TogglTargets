//: Playground - noun: a place where people can play

import Foundation
import Result
import ReactiveSwift
@testable import TogglGoals

typealias SessionProducer = SignalProducer<URLSession, NoError>
typealias APIEntityProducer<EntityType> = SignalProducer<EntityType, APIAccessError>
typealias WorkspaceID = Int64
typealias ProjectID = Int64
typealias IndexedProjects = [ProjectID : Project]
typealias ProjectsProducerProducer = SignalProducer<APIEntityProducer<[Project]>, NoError>

private let _apiCredential = MutableProperty<TogglAPICredential?>(nil)

let session: MutableProperty<URLSession?> = {
    let ses = MutableProperty<URLSession?>(nil)
    ses <~ _apiCredential.producer.skipNil().map { URLSession(togglAPICredential: $0) }
    return ses
}()

func makeProfileProducer(session: SessionProducer) -> APIEntityProducer<Profile> {
    return session.map {
        $0.togglAPIRequestProducer(for: MeService.endpoint, decoder: MeService.decodeProfile)
    }.flatten(.latest)
}
