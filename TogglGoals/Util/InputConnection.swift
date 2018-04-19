//
//  SignalConnection.swift
//  TogglGoals
//
//  Created by David Dávila on 16.04.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation
import Result
import ReactiveSwift

extension SignalProducerConvertible where Value: OptionalProtocol, Error == NoError  {
    func latest<T>(_ mapper: @escaping (Value.Wrapped) -> SignalProducer<T, NoError>) -> SignalProducer<T, NoError> {
        return producer.skipNil().map(mapper).flatten(.latest)
    }
}
