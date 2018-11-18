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
