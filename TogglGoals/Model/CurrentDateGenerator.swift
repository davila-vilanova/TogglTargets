//
//  CurrentTimeProducer.swift
//  TogglGoals
//
//  Created by David Dávila on 11.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

/// Publishes `Date` values representing the current date, updated on demand.
/// It makes sense for it to have to be a class so multiple parts of an application can share
/// references to it and a current date update triggered by one part is to be received by the other parts.
protocol CurrentDateGeneratorProtocol: class {
    var currentDate: Property<Date> { get }
    func triggerUpdate()

    var producer: SignalProducer<Date, NoError> { get }
    var updateTrigger: BindingTarget<Void> { get }
}

/// Implements `CurrentDateProducerProtocol` as a singleton to ensure the whole application
/// gets the same updates to the current date.
class CurrentDateGenerator: CurrentDateGeneratorProtocol {
    static var shared: CurrentDateGenerator = CurrentDateGenerator()

    internal lazy var currentDate = Property(initial: scheduler.currentDate, then: currentDatePipe.output)
    private lazy var currentDatePipe = Signal<Date, NoError>.pipe()

    var producer: SignalProducer<Date, NoError> {
        return currentDate.producer
    }

    var updateTrigger: BindingTarget<Void> {
        return BindingTarget<Void>(on: scheduler, lifetime: lifetime) { [weak self] in
            self?.triggerUpdate()
        }
    }

    /// The lifetime (and lifetime token) associated to this instance's binding targets.
    private let (lifetime, token) = Lifetime.make()
    private let scheduler = QueueScheduler.init(name: "CurrentTimeProducer-scheduler")

    /// Don't create instances of it, access the `shared` one instead.
    private init() { }

    func triggerUpdate() {
        currentDatePipe.input.send(value: scheduler.currentDate)
    }
}

