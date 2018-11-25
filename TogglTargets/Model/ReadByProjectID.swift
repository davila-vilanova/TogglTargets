//
//  ReadByProjectID.swift
//  TogglTargets
//
//  Created by David Dávila on 16.04.18.
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
import Result
import ReactiveSwift

/// Any function which takes a project ID as input and returns a producer that emits values over time corresponding to
/// the project associated with that project ID.
typealias ReadProject = (ProjectID) -> SignalProducer<Project?, NoError>

/// Any function which takes a project ID as input and returns a producer that emits values over time corresponding to
/// the report associated with that project ID.
typealias ReadReport = (ProjectID) -> SignalProducer<TwoPartTimeReport?, NoError>

/// Any function which takes a project ID as input and returns a producer that emits values over time corresponding to
/// the time target associated with that project ID.
///
/// - note: `nil` timeTarget values represent a target that does not exist yet or that has been deleted.
typealias ReadTimeTarget = (ProjectID) -> SignalProducer<TimeTarget?, NoError>
