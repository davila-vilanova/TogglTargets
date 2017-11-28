//
//  StoreProfileCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias StoreProfileCacheAction  = Action<Profile, (), NoError>
func makeStoreProfileCacheAction() -> StoreProfileCacheAction {
    return StoreProfileCacheAction { profile in
        SignalProducer.never // TODO
    }
}
