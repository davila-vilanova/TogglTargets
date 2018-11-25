//
//  TimeTargetsStore.swift
//  TogglTargets
//
//  Created by David Davila on 01.02.17.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SQLite
import Result
import ReactiveSwift

typealias ProjectIdIndexedTimeTargets = [ProjectID: TimeTarget]

/// Producer of `ProjectIDsByTimeTargets.Update` values that when started emits a `full(ProjectIDsByTimeTargets)` value
/// which can be followed by full or incremental updates.
typealias ProjectIDsByTimeTargetsProducer = SignalProducer<ProjectIDsByTimeTargets.Update, NoError>

/// An entity that keeps track of `TimeTarget` values.
protocol TimeTargetsStore {

    /// Function which takes a project ID as input and returns a producer that emits values over time corresponding to
    /// the time target associated with that project ID.
    ///
    /// - note: `nil` target values represent a time target that does not exist yet or that has been deleted.
    var readTimeTarget: ReadTimeTarget { get }

    /// Target which accepts new (or edited) timeTarget values.
    var writeTimeTarget: BindingTarget<TimeTarget> { get }

    /// Target which for each received project ID removes the timeTarget associated with that project ID.
    var deleteTimeTarget: BindingTarget<ProjectID> { get }
}
