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
}

class PreferenceStore<PreferenceType: StorableInUserDefaults> {

    lazy var output = Property(_output)
    var input: BindingTarget<Signal<PreferenceType, NoError>> { return _input.deoptionalizedBindingTarget }

    init(userDefaults: Property<UserDefaults>,
         scheduler: Scheduler) {
        self.userDefaults = userDefaults
        self.scheduler = scheduler

        // The first value sent through the output comes from reading the user defaults
        _output <~ userDefaults.producer
            .map { PreferenceType(userDefaults: $0) }
            .take(first: 1)
            .skipNil()

        // The latest source assigned to input will:
        //  * update the persisted value
        //  * forward the value through the output
        let inputValues = _input.producer.skipNil().flatten(.latest)
        persistValue <~ userDefaults.producer.combineLatest(with: inputValues)
        _output <~ inputValues
    }


    // MARK: - Private

    private let userDefaults: Property<UserDefaults>
    private let scheduler: Scheduler

    private lazy var _input = MutableProperty<Signal<PreferenceType, NoError>?>(nil)
    private lazy var _output = MutableProperty<PreferenceType?>(nil)

    private let (lifetime, token) = Lifetime.make()

    private lazy var persistValue =
        BindingTarget<(UserDefaults, PreferenceType)>(on: scheduler, lifetime: lifetime) {
            (userDefaults, preferenceType) in preferenceType.write(to: userDefaults)
    }
}
