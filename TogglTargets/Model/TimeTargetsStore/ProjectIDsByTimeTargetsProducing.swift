//
//  ProjectIDsByTimeTargetsProducing.swift
//  TogglTargets
//
//  Created by David Dávila on 09.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// An entity that receives a stream of collections of project IDs and produces a stream of
/// `ProjectIDsByTimeTargets` values and incremental updates generated by matching the received project IDs
/// against the time targets and changes to the time targets it has knowledge of.
protocol ProjectIDsByTimeTargetsProducing {
    /// Target that accepts and array of unsorted project IDs that will be matched against the time targets
    /// that this store has knowledge of.
    var projectIDs: BindingTarget<[ProjectID]> { get }

    /// Producer of `ProjectIDsByTimeTargets.Update` values that when started emits a
    // `full(ProjectIDsByTimeTargets)` value which can be followed by full or
    /// incremental updates, corresponding to the `ProjectIDsByTimeTargets` generated
    /// by matching project IDs provided to the `projectIDs` target against the
    /// time targets this store knows about.
    var projectIDsByTimeTargetsProducer: ProjectIDsByTimeTargetsProducer { get }
}
