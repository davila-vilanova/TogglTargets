//
//  StoreProjectsCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 19.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias StoreProjectsCacheAction = Action<IndexedProjects?, (), NoError>
func makeStoreProjectsCacheAction() -> StoreProjectsCacheAction {
    return StoreProjectsCacheAction { projects in
        if projects != nil {
            print("would store projects in cache")
        } else {
            print("would delete projects from cache")
        }
        return SignalProducer.empty // TODO
    }
}
