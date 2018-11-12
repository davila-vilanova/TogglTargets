//
//  TimeTargetsStore.swift
//  TogglTargets
//
//  Created by David Davila on 01.02.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import SQLite
import Result
import ReactiveSwift

typealias ProjectIdIndexedTimeTargets = [ProjectID: TimeTarget]

/// Producer of `ProjectIDsByTimeTargets.Update` values that when started emits a
// `full(ProjectIDsByTimeTargets)` value which can be followed by full or
/// incremental updates.
typealias ProjectIDsByTimeTargetsProducer = SignalProducer<ProjectIDsByTimeTargets.Update, NoError>

/// An entity that keeps track of `TimeTarget` values.
protocol TimeTargetsStore {

    /// Function which takes a project ID as input and returns a producer that
    /// emits values over time corresponding to the time target associated with that
    /// project ID.
    ///
    /// - note: `nil` target values represent a time target that does not exist yet or
    ///         that has been deleted.
    var readTimeTarget: ReadTimeTarget { get }

    /// Target which accepts new (or edited) timeTarget values.
    var writeTimeTarget: BindingTarget<TimeTarget> { get }

    /// Target which for each received project ID removes the timeTarget associated with that project ID.
    var deleteTimeTarget: BindingTarget<ProjectID> { get }
}
