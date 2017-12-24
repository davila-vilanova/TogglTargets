//
//  RetrieveProfileCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias RetrieveProfileCacheAction = Action<(), Profile?, NoError>
func makeRetrieveProfileCacheAction() -> RetrieveProfileCacheAction {
    return RetrieveProfileCacheAction {
        SignalProducer<Profile?, NoError>(value: nil) // TODO
    }
}
