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

typealias StoreProfileCacheAction = Action<Profile?, (), NoError>
func makeStoreProfileCacheAction() -> StoreProfileCacheAction {
    return StoreProfileCacheAction { profile in
        if profile != nil {
            print("would store profile in cache")
        } else {
            print("would delete profile from cache")
        }
        return SignalProducer.empty // TODO
    }
}
