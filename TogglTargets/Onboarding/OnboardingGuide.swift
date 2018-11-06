//
//  OnboardingGuide.swift
//  TogglTargets
//
//  Created by David Dávila on 03.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

private let onboardingNotPendingKey = "OnboardingNotPending"
private let showStepDelay: TimeInterval = 0.25

struct OnboardingStep {
    let identifier: OnboardingStepIdentifier
    let text: String
    let allowContinue: Bool
    let preferredEdge: NSRectEdge

    init(identifier: OnboardingStepIdentifier,
         text: String,
         allowContinue: Bool = false,
         preferredEdge: NSRectEdge = .maxX) {
        self.identifier = identifier
        self.text = text
        self.allowContinue = allowContinue
        self.preferredEdge = preferredEdge
    }
}

class OnboardingGuide {
    var lifetime: Lifetime
    private let token: Lifetime.Token

    private let _onboardingEnded = MutableProperty<Void?>(nil)

    var onboardingEnded: SignalProducer<Void, NoError> {
        return _onboardingEnded.producer.skipNil()
    }

    private let steps: [OnboardingStep]

    private lazy var
    targetViewEventHolders: [OnboardingStepIdentifier: MutableProperty<Signal<NSView, NoError>.Event?>] = {
        var holders =
            [OnboardingStepIdentifier: MutableProperty<Signal<NSView, NoError>.Event?>](minimumCapacity: steps.count)
        for step in steps {
            holders[step.identifier] = MutableProperty<Signal<NSView, NoError>.Event?>(nil)
        }
        return holders
    }()

    private lazy var sortedTargetViewEventHolders: [MutableProperty<Signal<NSView, NoError>.Event?>] = {
       var sorted = [MutableProperty<Signal<NSView, NoError>.Event?>]()
        for step in steps {
            guard let holder = targetViewEventHolders[step.identifier] else {
                assert(false)
                continue
            }
            sorted.append(holder)
        }
        return sorted
    }()

    func register(_ registree: AnyObject) {
        func connect(_ viewProducer: SignalProducer<NSView, NoError>,
                     toViewHolderFor stepIdentifier: OnboardingStepIdentifier) {
            func take(from viewProducer: SignalProducer<NSView, NoError>, stepIdentifier: OnboardingStepIdentifier)
                -> SignalProducer<Signal<NSView, NoError>.Event, NoError> {
                    func moveOnButtonPressed(for stepId: OnboardingStepIdentifier) -> SignalProducer<Void, NoError> {
                        return stepViewController.moveOnToNextStep.filter { $0 == stepId }
                            .map { _ in () }.take(first: 1)
                    }
                    return viewProducer.take(until: moveOnButtonPressed(for: stepIdentifier)).materialize()
            }
            guard let holder = targetViewEventHolders[stepIdentifier] else {
                print("+++ holder for \(stepIdentifier) does not exist")
                return
            }
            if holder.value != nil {
                print("+++ holder for \(stepIdentifier) already holds a non nil value: \(holder.value!)")
            }
            holder <~ take(from: viewProducer, stepIdentifier: stepIdentifier)
        }

        if let reg = registree as? OnboardingTargetViewsProvider {
            for (stepIdentifier, targetView) in reg.onboardingTargetViews {
                connect(targetView, toViewHolderFor: stepIdentifier)
            }
        }
    }

    private let delayScheduler = QueueScheduler()

    init(steps: [OnboardingStep], defaults: UserDefaults) {
        assert(!steps.isEmpty)
        self.steps = steps

        (lifetime, token) = Lifetime.make()

        func extractViewProducer(_ prop: MutableProperty<Signal<NSView, NoError>.Event?>)
            -> SignalProducer<NSView, NoError> {
                return prop.producer.skipNil().dematerialize()
        }

        let views = SignalProducer(sortedTargetViewEventHolders)
            .map(extractViewProducer)
            .flatten(.concat)
        let windowAttachedViews = views.zip(with:
            views.map {
                $0.reactive.producer(forKeyPath: "window")
                    .skipNil().filterMap { $0 as? NSWindow }
                    .take(first: 1)
                }
                .flatten(.concat))
            .map { $0.0 }

        let sortedViewTerminations = SignalProducer(sortedTargetViewEventHolders)
            .map {
                $0.producer.skipNil()
                    .filter { $0.isTerminating }
                    .map { _ in () }
                    .take(first: 1)
            }
            .flatten(.concat)

        let abortOnboardingRequested = stepViewController.requestAbortOnboarding

        let pacedSteps = SignalProducer(steps).zip(with: windowAttachedViews).take(until: abortOnboardingRequested)

        let lastStepStarted = pacedSteps.materialize().filter { $0.isCompleted }.map { _ in () }
        let lastStepShown = lastStepStarted.take(first: 1).then(stepPopoverDelegate.popoverDidShowTrigger.producer)
        let lastStepClosed = lastStepShown.take(first: 1).then(stepPopoverDelegate.popoverDidCloseTrigger.producer)
        let onboardingEnded = SignalProducer.merge(abortOnboardingRequested, lastStepClosed)

        let showPopover: BindingTarget<(NSView, NSRectEdge)> = stepPopover.reactive.makeBindingTarget { (pop, target) in
            let (view, edge) = target
            pop.show(relativeTo: view.bounds, of: view, preferredEdge: edge)
        }
        let closePopover: BindingTarget<Void> = stepPopover.reactive.makeBindingTarget { pop, _ in pop.close() }

        closePopover <~ SignalProducer.merge(sortedViewTerminations, abortOnboardingRequested)
        showPopover <~ pacedSteps.map { step, view in (view, step.preferredEdge) }

        stepViewController.representedStep <~
            pacedSteps.zip(with: stepPopoverDelegate.popoverDidCloseTrigger.producer.prefix(value: ())).map { $0.0.0 }

        stepViewController.configureForLastStep <~ lastStepStarted

        let markOnboardingAsNotPending: BindingTarget<Void> = defaults.reactive.makeBindingTarget { defaults, _ in
            defaults.set(true, forKey: onboardingNotPendingKey)
        }

        markOnboardingAsNotPending <~ onboardingEnded
        _onboardingEnded <~ onboardingEnded
    }

    private lazy var stepViewController =
        OnboardingStepViewController(nibName: "OnboardingStepViewController", bundle: nil)

    private lazy var stepPopover: NSPopover = {
        let popover = NSPopover()
        popover.contentViewController = stepViewController
        popover.behavior = .applicationDefined
        popover.delegate = stepPopoverDelegate
        return popover
    }()

    private lazy var stepPopoverDelegate = PopoverDelegate()

    static func shouldOnboard(_ defaults: UserDefaults) -> Bool {
        return !defaults.bool(forKey: onboardingNotPendingKey)
    }
}

protocol OnboardingTargetViewsProvider {
    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, NoError>] { get }
}

private class PopoverDelegate: NSObject, NSPopoverDelegate {
    private let _popoverDidShowTrigger = MutableProperty<Void?>(nil)

    private let _popoverDidCloseTrigger = MutableProperty<Void?>(nil)

    var popoverDidShowTrigger: Signal<Void, NoError> {
        return _popoverDidShowTrigger.signal.skipNil()
    }

    var popoverDidCloseTrigger: Signal<Void, NoError> {
        return _popoverDidCloseTrigger.signal.skipNil()
    }

    func popoverDidShow(_ notification: Notification) {
        _popoverDidShowTrigger.value = ()
    }

    func popoverDidClose(_ notification: Notification) {
        _popoverDidCloseTrigger.value = ()
    }
}
