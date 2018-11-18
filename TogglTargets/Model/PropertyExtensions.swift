//
//  PropertyExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 25.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

extension MutablePropertyProtocol where Value: OptionalProtocol {

    /// Returns a binding target that only accepts non optional values.
    public var deoptionalizedBindingTarget: BindingTarget<Value.Wrapped> {
        return BindingTarget(lifetime: lifetime) { [unowned self] (neverNil: Value.Wrapped) in
            self.value = Value(reconstructing: neverNil)
        }
    }
}
