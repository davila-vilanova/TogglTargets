//
//  SignalConnection.swift
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
import ReactiveSwift

extension SignalProducerConvertible where Value: OptionalProtocol, Error == Never {

    /// Selects and flattens the chosen producer from the connection interface.
    /// Use on a property that holds the value of the latest connection to extract the values of a singled out producer
    /// that is part of the interface.
    ///
    /// - parameters:
    ///   - selector: A function that receives a non `nil` connection value and extracts the desired producer.
    ///
    /// - returns: A producer of values emited by the selected producer.
    func latestOutput<T>(_ selector: @escaping (Value.Wrapped) -> SignalProducer<T, Never>)
        -> SignalProducer<T, Never> {
            return producer.skipNil().map(selector).flatten(.latest)
    }
}

extension SignalProducerConvertible where Error == Never {

    /// Binds self to the latest binding target emited by the provided producer.
    ///
    /// - parameters:
    ///   - bindingTargetProducer: A producer of binding targets to which to bind self. Every time the provided producer
    ///                            sends a new binding target the previous bound (if any) will be disposed and a new one
    ///                            will be created.
    ///
    /// - returns: A disposable that can be used to break the active bound.
    @discardableResult
    func bindOnlyToLatest(_ bindingTargetProducer: SignalProducer<BindingTarget<Value>, Never>) -> Disposable {
        let disposable = SerialDisposable()
        bindingTargetProducer.startWithValues { target in
            disposable.inner = target <~ self.producer
        }
        return disposable
    }
}
