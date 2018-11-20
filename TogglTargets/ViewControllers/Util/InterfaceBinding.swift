//
//  SignalConnection.swift
//  TogglTargets
//
//  Created by David Dávila on 16.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

extension SignalProducerConvertible where Value: OptionalProtocol, Error == NoError {

    /// Selects and flattens the chosen producer from the connection interface.
    /// Use on a property that holds the value of the latest connection to extract the values of a singled out producer
    /// that is part of the interface.
    ///
    /// - parameters:
    ///   - selector: A function that receives a non `nil` connection value and extracts the desired producer.
    ///
    /// - returns: A producer of values emited by the selected producer.
    func latestOutput<T>(_ selector: @escaping (Value.Wrapped) -> SignalProducer<T, NoError>)
        -> SignalProducer<T, NoError> {
            return producer.skipNil().map(selector).flatten(.latest)
    }
}

extension SignalProducerConvertible where Error == NoError {

    /// Binds self to the latest binding target emited by the provided producer.
    ///
    /// - parameters:
    ///   - bindingTargetProducer: A producer of binding targets to which to bind self. Every time the provided producer
    ///                            sends a new binding target the previous bound (if any) will be disposed and a new one
    ///                            will be created.
    ///
    /// - returns: A disposable that can be used to break the active bound.
    @discardableResult
    func bindOnlyToLatest(_ bindingTargetProducer: SignalProducer<BindingTarget<Value>, NoError>) -> Disposable {
        let disposable = SerialDisposable()
        bindingTargetProducer.startWithValues { target in
            disposable.inner = target <~ self.producer
        }
        return disposable
    }
}
