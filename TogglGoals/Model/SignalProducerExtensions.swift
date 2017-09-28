//
//  SignalProducerExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 24.09.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

extension SignalProducer {
    func mapToNoError() -> SignalProducer<Value, NoError> {
        return flatMapError { error in
            // log message

            return SignalProducer<Value, NoError>.empty
        }
    }
}
