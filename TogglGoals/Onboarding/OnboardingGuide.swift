//
//  OnboardingGuide.swift
//  TogglGoals
//
//  Created by David Dávila on 03.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

fileprivate let OnboardingNotPendingKey = "OnboardingNotPending"
fileprivate let ShowStepDelay: TimeInterval = 0.25

struct OnboardingStep {
    let identifier: OnboardingStepIdentifier
    let text: String
    let allowContinue: Bool
    let preferredEdge: NSRectEdge
    
    init(identifier: OnboardingStepIdentifier, text: String, allowContinue: Bool = false, preferredEdge: NSRectEdge = .maxX) {
        self.identifier = identifier
        self.text = text
        self.allowContinue = allowContinue
        self.preferredEdge = preferredEdge
    }
}

class OnboardingGuide {
    var lifetime: Lifetime
    private let token: Lifetime.Token

    let onboardingEnded: SignalProducer<Void, NoError>

    private let steps: [OnboardingStep]
    
    private lazy var targetViewEventHolders: [OnboardingStepIdentifier : MutableProperty<Signal<NSView, NoError>.Event?>] = {
        var holders = [OnboardingStepIdentifier : MutableProperty<Signal<NSView, NoError>.Event?>](minimumCapacity: steps.count)
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
        func connect(_ viewProducer: SignalProducer<NSView, NoError>, toViewHolderFor stepIdentifier: OnboardingStepIdentifier) {
            func take(from viewProducer: SignalProducer<NSView, NoError>, stepIdentifier: OnboardingStepIdentifier)
                -> SignalProducer<Signal<NSView, NoError>.Event, NoError> {
                    func moveOnButtonPressed(for stepId: OnboardingStepIdentifier) -> SignalProducer<Void, NoError> {
                        return stepViewController.moveOnToNextStep.filter { $0 == stepId }.map { _ in () }.take(first: 1)
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
        
        if let r = registree as? OnboardingTargetViewsProvider {
            for (stepIdentifier, targetView) in r.onboardingTargetViews {
                connect(targetView, toViewHolderFor: stepIdentifier)
            }
        }
    }
    
    private let delayScheduler = QueueScheduler()
    
    init(steps: [OnboardingStep], defaults: UserDefaults) {
        assert(!steps.isEmpty)
        self.steps = steps
        
        (lifetime, token) = Lifetime.make()
        let onboardingEnded = MutableProperty<Void?>(nil)
        lifetime.observeEnded {
            _ = onboardingEnded
        }
        self.onboardingEnded = onboardingEnded.producer.skipNil()

        func extractViewProducer(_ prop: MutableProperty<Signal<NSView, NoError>.Event?>) -> SignalProducer<NSView, NoError> {
            return prop.producer.skipNil().dematerialize()
        }

        let views = SignalProducer(sortedTargetViewEventHolders)
            .map(extractViewProducer)
            .flatten(.concat)

        let lastStepFinished = targetViewEventHolders[steps.last!.identifier]!
            .producer.skipNil().filter { $0.isCompleted }.map { _ in () }

        let onboardingAborted = stepViewController.stopOnboarding
        let onboardingClosed = SignalProducer.merge(onboardingAborted, lastStepFinished)

        let currentTargetViewCompleted = SignalProducer(sortedTargetViewEventHolders)
            .combinePrevious()
            .map {
                $0.0.producer.skipNil()
                    .filter { $0.isCompleted }
                    .take(until: extractViewProducer($0.1).map { _ in () })
                    .map { _ in () }
            }.flatten(.concat)
            .take(until: onboardingAborted)

        let windowsAsAvailable = views.map { $0.reactive.producer(forKeyPath: "window").skipNil().filterMap { $0 as? NSWindow }.take(first: 1) }.flatten(.concat)
        let windowAttachedViews = views.zip(with: windowsAsAvailable).map { $0.0 } // TODO: alternatively use https://developer.apple.com/documentation/appkit/nsview/1483329-viewdidmovetowindow
        
        let pacedSteps = SignalProducer(steps).zip(with: windowAttachedViews).take(until: onboardingAborted)
        showStep <~ pacedSteps

        let closePopover: BindingTarget<Void> = stepPopover.reactive.makeBindingTarget { pop, _ in pop.close() }
        closePopover <~ SignalProducer.merge(currentTargetViewCompleted, onboardingClosed)

        let lastStepStarted = pacedSteps.materialize().filter { $0.isCompleted }.map { _ in () }
        stepViewController.configureForLastStep <~ lastStepStarted

        let markOnboardingAsNotPending: BindingTarget<Void> = defaults.reactive.makeBindingTarget { defaults, _ in
            defaults.set(true, forKey: OnboardingNotPendingKey)
        }

        markOnboardingAsNotPending <~ onboardingClosed
        onboardingEnded <~ onboardingClosed
    }
    
    private lazy var stepViewController = OnboardingStepViewController(nibName: NSNib.Name(rawValue: "OnboardingStepViewController"), bundle: nil)

    private lazy var stepPopover: NSPopover = {
        let popover = NSPopover()
        popover.contentViewController = stepViewController
        popover.behavior = .applicationDefined
        return popover
    }()
    
    private lazy var showStep: BindingTarget<(OnboardingStep, NSView)> =
        BindingTarget(on: UIScheduler(), lifetime: lifetime) { [unowned self] (step, targetView) in
            func updateAndShow() {
                self.stepViewController.representedStep <~ SignalProducer(value: step)
                self.stepPopover.show(relativeTo: targetView.bounds, of: targetView, preferredEdge: step.preferredEdge)
            }
            if self.stepPopover.isShown {
               self.stepPopover.close()
                self.delayScheduler.schedule(after: Date() + ShowStepDelay) {
                    UIScheduler().schedule(updateAndShow)
                }
            } else {
                updateAndShow()
            }
    }

    static func shouldOnboard(_ defaults: UserDefaults) -> Bool {
        return !defaults.bool(forKey: OnboardingNotPendingKey)
    }
}

protocol OnboardingTargetViewsProvider {
    var onboardingTargetViews: [OnboardingStepIdentifier : SignalProducer<NSView, NoError>] { get }
}
