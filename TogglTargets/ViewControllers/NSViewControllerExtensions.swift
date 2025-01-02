//
//  NSViewControllerExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 08.10.18.
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

import Cocoa
import ReactiveSwift

extension NSViewController {

    /// Registers this view controller and all its children view controllers with the provided onboarding guide so that
    /// they can provide any target views involved in the onboarding process.
    /// Any future child view controllers will be registered as they become available.
    ///
    /// - parameters:
    ///   - guide: The onboarding guide into which to register.
    func setOnboardingGuide(_ guide: OnboardingGuide) {
        guide.register(self)

        guide.lifetime += reactive.producer(forKeyPath: "childViewControllers")
            .skipNil().compactMap { $0 as? [NSViewController] }
            .map { SignalProducer($0) }
            .flatten(.concat)
            .uniqueValues()
            .startWithValues { [weak guide] controller in
                guard let guide = guide else {
                    return
                }
                controller.setOnboardingGuide(guide)
        }
    }
}

extension NSViewController {

    /// Sends a single empty value when this controller's viewDidLoad method is invoked or if it has already been
    /// invoked and then completes.
    var viewDidLoadProducer: SignalProducer<Void, Never> {
        return isViewLoadedProducer.filter { $0 }.map(value: ())
    }

    private var isViewLoadedProducer: SignalProducer<Bool, Never> {
        return SignalProducer<Bool, Never> { [weak self] observer, lifetime in
            guard let viewController = self else {
                observer.sendCompleted()
                return
            }
            if viewController.isViewLoaded {
                observer.send(value: true)
                observer.sendCompleted()
            } else {
                observer.send(value: false)
                lifetime += viewController.viewDidLoadTrigger.map { true }.observe(observer)
            }
            }.start(on: UIScheduler())
    }

    /// Sends a single empty value when this controller's viewDidLoad method is invoked and then completes.
    private var viewDidLoadTrigger: Signal<Void, Never> {
        return reactive.trigger(for: #selector(NSViewController.viewDidLoad)).take(first: 1)
    }
}
