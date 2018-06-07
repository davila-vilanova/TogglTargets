//
//  PreferenceStore.swift
//  TogglGoals
//
//  Created by David Dávila on 10.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import Result

protocol StorableInUserDefaults {
    init?(userDefaults: UserDefaults)
    func write(to userDefaults: UserDefaults)
    static func delete(from userDefaults: UserDefaults)
}

class PreferenceStore<PreferenceType: StorableInUserDefaults> {

    let output: Property<PreferenceType?>
    let input: BindingTarget<PreferenceType?>

    init(userDefaults: Property<UserDefaults>,
         scheduler: Scheduler) {
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
