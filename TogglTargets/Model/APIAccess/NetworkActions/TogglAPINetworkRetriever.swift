//
//  TogglAPINetworkRetriever.swift
//  TogglTargets
//
//  Created by David Dávila on 22.12.17.
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
import ReactiveSwift

/// A function or closure that takes a string representing an endpoint in the Toggl API and a `URLSession` instance to
/// access the network and returns a `SignalProducer` that produces a single value of the retrieved entity or an
/// `APIAccessError`.
typealias TogglAPINetworkRetriever<Entity> = (String, URLSession) -> SignalProducer<Entity, APIAccessError>
