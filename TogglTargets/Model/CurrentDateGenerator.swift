//
//  CurrentTimeProducer.swift
//  TogglTargets
//
//  Created by David Dávila on 11.12.17.
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
import Result

/// Publishes `Date` values representing the current date, updated on demand.
/// It makes sense for it to have to be a class so that multiple parts of an application can share references to it and
/// a current date update triggered by one party will be received by the rest.
protocol CurrentDateGeneratorProtocol: class {

    /// The last generated current date.
    var currentDate: Property<Date> { get }

    /// Determine the current date and update the value of `currentDate`.
    func triggerUpdate()

    /// Producer of values corresponding to the current date.
    var producer: SignalProducer<Date, NoError> { get }

    /// Binding target that will trigger an update to the current date whenever
    /// an empty value is received.
    var updateTrigger: BindingTarget<Void> { get }
}

/// Publishes `Date` values representing the current date, updated on demand.
/// It's a singleton to ensure the whole application gets the same updates to the current date.
class CurrentDateGenerator: CurrentDateGeneratorProtocol {

    /// The `CurrentDateGenerator` instance to be shared across the application.
    static var shared: CurrentDateGenerator = CurrentDateGenerator()

    /// The last generated current date.
    internal lazy var currentDate = Property(initial: scheduler.currentDate, then: currentDatePipe.output)

    /// The pipe that conveys generated current date values.
    private lazy var currentDatePipe = Signal<Date, NoError>.pipe()

    /// Producer of values corresponding to the current date.
    var producer: SignalProducer<Date, NoError> {
        return currentDate.producer
    }

    /// Binding target that will trigger an update to the current date whenever an empty value is received.
    var updateTrigger: BindingTarget<Void> {
        return BindingTarget<Void>(on: scheduler, lifetime: lifetime) { [weak self] in
            self?.triggerUpdate()
        }
    }

    /// The lifetime (and lifetime token) associated to this instance's binding target.
    private let (lifetime, token) = Lifetime.make()

    /// Scheduler used to determine the current date and associated to this instance's binding target.
    private let scheduler = QueueScheduler.init(name: "CurrentTimeProducer-scheduler")

    /// Don't create instances of it, access the `shared` one instead.
    private init() { }

    /// Determine the current date and update the value of `currentDate`.
    func triggerUpdate() {
        currentDatePipe.input.send(value: scheduler.currentDate)
    }
}
