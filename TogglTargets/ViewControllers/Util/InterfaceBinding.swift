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

extension SignalProducerConvertible where Value: OptionalProtocol, Error == NoError  {
    func latestOutput<T>(_ selector: @escaping (Value.Wrapped) -> SignalProducer<T, NoError>) -> SignalProducer<T, NoError> {
        return producer.skipNil().map(selector).flatten(.latest)
    }
}

extension SignalProducerConvertible where Error == NoError {
    @discardableResult
    func bindOnlyToLatest(_ bindingTargetProducer: SignalProducer<BindingTarget<Value>, NoError>) -> Disposable {
        let disposable = SerialDisposable()
        bindingTargetProducer.startWithValues { target in
            disposable.inner = target <~ self.producer
        }
        return disposable
    }
}
