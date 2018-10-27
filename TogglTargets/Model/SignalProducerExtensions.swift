//
//  SignalProducerExtensions.swift
//  TogglTargets
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

fileprivate let DefaultPlaceholderForNil = "--"

extension SignalProducer where Value == Int? {
    func mapToString(placeholderForNil: String = DefaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (valueOrNil : Int?) -> String in
            if let value = valueOrNil {
                return "\(value)"
            } else {
                return placeholderForNil
            }
        }
    }

    func mapToNonNil(valueForNil: Int = 0) -> SignalProducer<Int, Error> {
        return map { (valueOrNil: Int?) -> Int in
            if let value = valueOrNil {
                return value
            } else {
                return valueForNil
            }
        }
    }
}

// TODO: Extension on DateComponentsFormatter?
extension SignalProducer where Value == TimeInterval? {
    func mapToString(timeFormatter: DateComponentsFormatter,
                     placeholderForNil: String = DefaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (timeOrNil: TimeInterval?) -> String in
            guard let time = timeOrNil else {
                return placeholderForNil
            }
            return timeFormatter.string(from: time) ?? placeholderForNil
        }
    }
}

extension SignalProducer where Value == TimeInterval {
    func mapToString(timeFormatter: DateComponentsFormatter,
                     placeholderForNil: String = DefaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? placeholderForNil
        }
    }
}

// TODO: Extension in NumberFormatter?
extension SignalProducer where Value == NSNumber? {
    func mapToNumberFormattedString(numberFormatter: NumberFormatter,
                                  placeholderForNil: String = DefaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (numberOrNil: NSNumber?) -> String in
            guard let number = numberOrNil else {
                return placeholderForNil
            }
            return numberFormatter.string(from: number) ?? placeholderForNil
        }
    }
}
