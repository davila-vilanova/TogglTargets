//
//  TimeTargetPersistenceProvider.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// An entity that provides persistent storage of `TimeTarget` values.
protocol TimeTargetPersistenceProvider {
    
    /// This property is populated with the result of retrieving all persisted time targets and updated with any 
    /// creation, update or deletion of any time targets.
    var allTimeTargets: MutableProperty<ProjectIdIndexedTimeTargets> { get }

    /// This binding target accepts and persists `TimeTarget` values.
    var persistTimeTarget: BindingTarget<TimeTarget> { get }

    /// Deletes the time targets associated with the project IDs it receives.
    var deleteTimeTarget: BindingTarget<ProjectID> { get }
}
