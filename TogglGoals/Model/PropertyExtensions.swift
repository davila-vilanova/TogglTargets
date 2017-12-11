//
//  PropertyExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 25.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

// TODO: Extension on BindingTargetProvider?
extension MutablePropertyProtocol where Value: OptionalProtocol {
    public var deoptionalizedBindingTarget: BindingTarget<Value.Wrapped> {
        return BindingTarget(lifetime: lifetime) { [unowned self] (neverNilValue: Value.Wrapped) in
            self.value = Value(reconstructing: neverNilValue)
        }
    }
}

extension PropertyProtocol where Value == Bool {
    var firstTrue: SignalProducer<Void, NoError> {
        return producer.filter { $0 }.take(first: 1).map { _ in () }
    }
}
