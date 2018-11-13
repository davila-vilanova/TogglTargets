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

private let defaultPlaceholderForNil = "--"

// TODO: Extension on DateComponentsFormatter?
extension SignalProducer where Value == TimeInterval? {
    func mapToString(timeFormatter: DateComponentsFormatter,
                     placeholderForNil: String = defaultPlaceholderForNil) -> SignalProducer<String, Error> {
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
                     placeholderForNil: String = defaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? placeholderForNil
        }
    }
}

// TODO: Extension in NumberFormatter?
extension SignalProducer where Value == NSNumber? {
    func mapToNumberFormattedString(numberFormatter: NumberFormatter,
                                    placeholderForNil: String = defaultPlaceholderForNil)
        -> SignalProducer<String, Error> {
            return map { (numberOrNil: NSNumber?) -> String in
                guard let number = numberOrNil else {
                    return placeholderForNil
                }
                return numberFormatter.string(from: number) ?? placeholderForNil
            }
    }
}
