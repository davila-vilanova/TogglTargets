//
//  Relay.swift
//  TogglGoals
//
//  Created by David Dávila on 21.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Result
import ReactiveSwift
import Foundation

/// Relay - some contraption whose input connects to a signal and has an output in the shape of a BindingSource
/// It might add a non-insignificant amount of overhead (*1), but dang it, it's handy (*2). FIXME
/// (*1) Values passing through this will hop from _bindingTarget -> observer / signal -> producer
/// Or is that a problem only when it involves switching schedulers?
/// (*2) It is useful to connect a source to a target when the source and the target are not available at the same time and
/// it's not feasible to know with certainty in which order they will become available.

class Relay<Value>: BindingTargetProvider, BindingSource {
    public var bindingTarget: BindingTarget<Value> {
        return _bindingTarget
    }

    public var producer: SignalProducer<Value, NoError>

    private let (lifetime, token) = Lifetime.make()

    // Cannot be a a non-optional constant because of its initializer's requirement to capture self
    private var _bindingTarget: BindingTarget<Value>!

    private let (signal, observer) = Signal<Value, NoError>.pipe()

    init() {
        producer = SignalProducer<Value, NoError>(signal)

        _bindingTarget = BindingTarget<Value>(lifetime: self.lifetime, action: { [unowned self] (value) in
            self.observer.send(value: value)
        })
    }
}
