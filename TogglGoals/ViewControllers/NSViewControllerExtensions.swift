//
//  NSViewControllerExtensions.swift
//  TogglGoals
//
//  Created by David Dávila on 08.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

extension NSViewController {
    /// "Registers" in the onboarding guide.
    /// Sets the onboarding guide in all child view controllers as they
    /// become available.
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
    var viewDidLoadTrigger: Signal<Void, NoError> {
        return reactive.trigger(for: #selector(NSViewController.viewDidLoad)).take(first: 1)
    }
    
    var isViewLoadedProducer: SignalProducer<Bool, NoError> {
        return SignalProducer<Bool, NoError> { [weak self] observer, lifetime in
            guard let viewController = self else {
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
    
    var viewDidLoadProducer: SignalProducer<Void, NoError> {
        return isViewLoadedProducer.filter { $0 }.map { _ in () }
    }
    
    //    var heldViewDidLoadProducer: SignalProducer<Void, NoError> {
    //        return viewDidLoadProducer.concat(SignalProducer.never)
    //    }
}
