//
//  PreferenceStore.swift
//  TogglTargets
//
//  Created by David Dávila on 10.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

/// Represents a data type that can store itself in the user defaults.
protocol StorableInUserDefaults {
    init?(userDefaults: UserDefaults)
    func write(to userDefaults: UserDefaults)
    static func delete(from userDefaults: UserDefaults)
}

/// Responsible for managing the storage and retrieval of a given user defaults datatype.
class PreferenceStore<PreferenceType: StorableInUserDefaults> {

    /// Outputs the latest stored value.
    let output: Property<PreferenceType?>

    /// Stores any received values. A new value will overwrite the previous one.
    let input: BindingTarget<PreferenceType?>

    /// Initializes a new store for a given datatype that immediately outputs the stored value.
    /// 
    ///
    /// - parameters:
    ///   - userDefaults: The userDefaults to use to retrieve and store values.
    ///   - scheduler: The scheduler in which to schedule the read and write operations issued by this store.
    ///   - defaultValue: The value to output if no value is stored in the user defaults. This affects the first value
    ///                   which is output, which is read from the user defaults. Subsequent `nil` values coming from the
    ///                   input will result in corresponding `nil` value being output.
    init(userDefaults: Property<UserDefaults>,
         scheduler: Scheduler,
         defaultValue: PreferenceType? = nil) {
        self.userDefaults = userDefaults
        self.scheduler = scheduler

        let inputBacker = MutableProperty<PreferenceType?>(nil)
        let outputBacker = MutableProperty<PreferenceType?>(nil)

        lifetime.observeEnded {
            _ = inputBacker
            _ = outputBacker
        }

        self.input = inputBacker.bindingTarget
        self.output = Property(outputBacker)

        // The first value sent through the output comes from reading the user defaults
        outputBacker <~ userDefaults.producer
            .map { PreferenceType(userDefaults: $0) }
            .take(first: 1)
            .map { $0 ?? defaultValue }

        // The latest source assigned to input will:
        //  * update the persisted value
        //  * forward the value through the output
        let inputValues = inputBacker.producer.skip(first: 1) // Skip first value (always nil)
        persistValue <~ userDefaults.producer.combineLatest(with: inputValues)
        outputBacker <~ inputValues
    }

    // MARK: - Private

    private let userDefaults: Property<UserDefaults>
    private let scheduler: Scheduler

    private let (lifetime, token) = Lifetime.make()

    private lazy var persistValue =
        BindingTarget<(UserDefaults, PreferenceType?)>(on: scheduler, lifetime: lifetime) { (userDefaults, value) in
            if let value = value {
                value.write(to: userDefaults)
            } else {
                PreferenceType.delete(from: userDefaults)
            }
    }
}
