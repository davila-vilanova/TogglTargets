//
//  RetrieveProjectsCacheAction.swift
//  TogglGoals
//
//  Created by David Dávila on 19.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

typealias RetrieveProjectsCacheAction = Action<(), IndexedProjects?, NoError>
func makeRetrieveProjectsCacheAction() -> RetrieveProjectsCacheAction {
    return RetrieveProjectsCacheAction {
        print("would retrieve projects from cache")
        return SignalProducer.empty // TODO
    }
}
