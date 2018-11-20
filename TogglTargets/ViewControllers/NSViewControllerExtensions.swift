//
//  NSViewControllerExtensions.swift
//  TogglTargets
//
//  Created by David Dávila on 08.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
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
            .skipNil().filterMap { $0 as? [NSViewController] }
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
    var viewDidLoadProducer: SignalProducer<Void, NoError> {
        return isViewLoadedProducer.filter { $0 }.map { _ in () }
    }

    private var isViewLoadedProducer: SignalProducer<Bool, NoError> {
        return SignalProducer<Bool, NoError> { [weak self] observer, lifetime in
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
    private var viewDidLoadTrigger: Signal<Void, NoError> {
        return reactive.trigger(for: #selector(NSViewController.viewDidLoad)).take(first: 1)
    }
}
