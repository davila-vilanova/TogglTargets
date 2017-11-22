//
//  LatestValueHoldingAction.swift
//  TogglGoals
//
//  Created by David Davila on 19.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

class LatestValueHoldingAction<Input, Output, Error: Swift.Error> {
    let wrappedAction: Action<Input, Output, Error>
    
    private let latestValue = MutableProperty<Output?>(nil)
    var values: SignalProducer<Output, NoError> { return latestValue.producer.skipNil() }
    
    init(wrapping action: Action<Input, Output, Error>) {
        wrappedAction = action
        latestValue <~ wrappedAction.values.logEvents(identifier: "wrappedAction.values", events: [.value])
    }
}

extension LatestValueHoldingAction {
    
}

extension LatestValueHoldingAction: BindingTargetProvider {
    public var bindingTarget: BindingTarget<Input> {
        return wrappedAction.bindingTarget
    }
}
