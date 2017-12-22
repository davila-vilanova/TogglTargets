//
//  TogglAPINetworkRetriever.swift
//  TogglGoals
//
//  Created by David Dávila on 22.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift

/// A function or closure that takes a string representing an endpoint in the
/// Toggl API and a `URLSession` instance to access the network and returns a
/// `SignalProducer` that produces a single value of the retrieved entity or an
/// `APIAccessError`
typealias TogglAPINetworkRetriever<Entity> = (String, URLSession) -> SignalProducer<Entity, APIAccessError>
