//
//  TimeTargetPersistenceProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

protocol TimeTargetPersistenceProvider {
    var persistTimeTarget: BindingTarget<TimeTarget> { get }
    var deleteTimeTarget: BindingTarget<ProjectID> { get }
    var allTimeTargets: MutableProperty<ProjectIdIndexedTimeTargets> { get }
}
