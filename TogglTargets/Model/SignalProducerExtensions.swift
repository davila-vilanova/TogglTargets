//
//  SignalProducerExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 24.09.17.
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

private let defaultPlaceholderForNil = "--"

extension SignalProducer where Value == TimeInterval? {

    /// Transforms a producer of optional `TimeInterval` values into a producer of string values using the provided
    /// `DateComponentsFormatter`.
    ///
    /// - parameters:
    ///   - timeFormatter: The `TimeFormatter` to format each of the `TimeInterval` values emitted by this producer
    ///                    into a string.
    ///   - placeholderForNil: The value to emit when this producer emits a `nil` value or if the formatter
    ///                        returs `nil`.
    ///
    /// - returns: A producer of formatted strings, each representing a time a interval value or a `nil` value.
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

    /// Transforms a producer of `TimeInterval` values into a producer of string values using the provided
    /// `DateComponentsFormatter`.
    ///
    /// - parameters:
    ///   - timeFormatter: The `TimeFormatter` to format each of the non `nil` values emitted by this producer into a
    ///                    string.
    ///   - placeholderForNil: The value to emit if the formatter returs nil.
    ///
    /// - returns: A producer of formatted strings, each representing a time a interval value or a `nil` value.
    func mapToString(timeFormatter: DateComponentsFormatter,
                     placeholderForNil: String = defaultPlaceholderForNil) -> SignalProducer<String, Error> {
        return map { (time: TimeInterval) -> String in
            return timeFormatter.string(from: time) ?? placeholderForNil
        }
    }
}

extension SignalProducer where Value == NSNumber? {

    /// Transforms a producer of optional `NSNumber` values into a producer of string values using the provided
    /// `NumberFormatter`.
    ///
    /// - parameters:
    ///   - timeFormatter: The `NumberFormatter` to format each of the non `nil` values emitted by this producer into a
    ///                    string.
    ///   - placeholderForNil: The value to emit when this producer emits a `nil` value or if the formatter returs nil.
    ///
    /// - returns: A producer of formatted strings, each representing a formatted numeric value or a `nil` value.
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
