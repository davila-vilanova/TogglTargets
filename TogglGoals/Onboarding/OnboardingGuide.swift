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
    enum Identifier: String {
        case login
        case closeLogin
        case selectProject
        case createGoal
        case setTargetHours
        case setWorkWeekdays
        case selectComputeStrategyFrom
        case seeTimeProgress
        case seeGoalStrategy
        case seeDayProgress
    }
    let identifier: Identifier
    let text: String
    let allowContinue: Bool
    let preferredEdge: NSRectEdge
    
    init(identifier: Identifier, text: String, allowContinue: Bool = false, preferredEdge: NSRectEdge = .maxX) {
        self.identifier = identifier
        self.text = text
        self.allowContinue = allowContinue
        self.preferredEdge = preferredEdge
    }
}

fileprivate let OnboardingSteps: [OnboardingStep] = [
    OnboardingStep(identifier: .login, text: NSLocalizedString("onboarding.step.login", comment: "onboarding step: login")),
    OnboardingStep(identifier: .closeLogin, text: NSLocalizedString("onboarding.step.close-login", comment: "onboarding step: close login")),
    OnboardingStep(identifier: .selectProject, text: NSLocalizedString("onboarding.step.select-project", comment: "onboarding step: select project")),
    OnboardingStep(identifier: .createGoal, text: NSLocalizedString("onboarding.step.create-goal", comment: "onboarding step: create goal")),
    OnboardingStep(identifier: .setTargetHours, text: NSLocalizedString("onboarding.step.set-target-hours", comment: "onboarding step: set target hours"), allowContinue: true, preferredEdge: .maxY),
    OnboardingStep(identifier: .setWorkWeekdays, text: NSLocalizedString("onboarding.step.set-work-weekdays", comment: "onboarding step: set work weekdays"), allowContinue: true),
    OnboardingStep(identifier: .selectComputeStrategyFrom, text: NSLocalizedString("onboarding.step.select-compute-from", comment: "onboarding step: select from which day to compute the goal strategy"), allowContinue: true),
    OnboardingStep(identifier: .seeTimeProgress, text: NSLocalizedString("onboarding.step.see-time-progress", comment: "onboarding step: see time progress"), allowContinue: true),
    OnboardingStep(identifier: .seeGoalStrategy, text: NSLocalizedString("onboarding.step.see-goal-strategy", comment: "onboarding step: see strategy to fulfill goal"), allowContinue: true),
    OnboardingStep(identifier: .seeDayProgress, text: NSLocalizedString("onboarding.step.see-day-progress", comment: "onboarding step: see day progress"), allowContinue: true),
]

class OnboardingGuide {
    var lifetime: Lifetime
    private let token: Lifetime.Token

    private var _isOnboarding = MutableProperty(false)
    var isOnboarding: Bool {
        return _isOnboarding.value
    }
    
    private lazy var targetViewEventHolders: [OnboardingStep.Identifier : MutableProperty<Signal<NSView, NoError>.Event?>] = {
        var holders = [OnboardingStep.Identifier : MutableProperty<Signal<NSView, NoError>.Event?>](minimumCapacity: OnboardingSteps.count)
        for step in OnboardingSteps {
            holders[step.identifier] = MutableProperty<Signal<NSView, NoError>.Event?>(nil)
        }
        return holders
    }()
    
    private lazy var sortedTargetViewEventHolders: [MutableProperty<Signal<NSView, NoError>.Event?>] = {
       var sorted = [MutableProperty<Signal<NSView, NoError>.Event?>]()
        for step in OnboardingSteps {
            guard let holder = targetViewEventHolders[step.identifier] else {
                assert(false)
                continue
            }
            sorted.append(holder)
        }
        return sorted
    }()
    
    func register(_ registree: AnyObject) {
        func connect(_ viewProducer: SignalProducer<NSView, NoError>, toViewHolderFor stepIdentifier: OnboardingStep.Identifier) {
            func take(from viewProducer: SignalProducer<NSView, NoError>, stepIdentifier: OnboardingStep.Identifier)
                -> SignalProducer<Signal<NSView, NoError>.Event, NoError> {
                    func moveOnButtonPressed(for stepId: OnboardingStep.Identifier) -> SignalProducer<Void, NoError> {
                        return stepViewController.moveOnToNextStep.filter { $0 == stepId }.map { _ in () }.take(first: 1)
                    }
                    return viewProducer.take(until: moveOnButtonPressed(for: stepIdentifier)).materialize()
            }
            guard let holder = targetViewEventHolders[stepIdentifier] else {
                assert(false)
                return
            }
            assert(holder.value == nil)
            holder <~ take(from: viewProducer, stepIdentifier: stepIdentifier)
        }
        
        if let r = registree as? OnboardingTargetViewsProvider {
            for (stepIdentifier, targetView) in r.onboardingTargetViews {
                connect(targetView, toViewHolderFor: stepIdentifier)
            }
        }
    }
    
    private let delayScheduler = QueueScheduler()
    
    init() {
        (lifetime, token) = Lifetime.make()
        
        assert(!OnboardingSteps.isEmpty)
        
        func extractViewProducer(_ prop: MutableProperty<Signal<NSView, NoError>.Event?>) -> SignalProducer<NSView, NoError> {
            return prop.producer.skipNil().dematerialize()
        }

        let views = SignalProducer(sortedTargetViewEventHolders)
            .map(extractViewProducer)
            .flatten(.concat)

        let onboardingAborted = stepViewController.stopOnboarding
        let onboardingClosed = endedViewController.close

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
        
        let pacedSteps = SignalProducer(OnboardingSteps).zip(with: windowAttachedViews).take(until: onboardingAborted)
        showStep <~ pacedSteps

        let closePopover: BindingTarget<Void> = stepPopover.reactive.makeBindingTarget { pop, _ in pop.close() }
        closePopover <~ SignalProducer.merge(currentTargetViewCompleted, onboardingClosed)

        let lastStepStarted = pacedSteps.materialize().filter { $0.isCompleted }.map { _ in () }
        stepViewController.configureForLastStep <~ lastStepStarted

        let lastStepFinished = targetViewEventHolders[OnboardingSteps.last!.identifier]!
            .producer.skipNil().filter { $0.isCompleted }.map { _ in () }

        stepPopover.reactive.makeBindingTarget { pop, controller in pop.contentViewController = controller }
            <~ SignalProducer(value: stepViewController).concat(SignalProducer.never).take(until: SignalProducer.merge(lastStepFinished, onboardingAborted)).concat(SignalProducer(value: endedViewController))

        let markOnboardingAsNotPending: BindingTarget<Void> = UserDefaults.standard.reactive.makeBindingTarget { defaults, _ in
            defaults.set(true, forKey: OnboardingNotPendingKey)
        }

        markOnboardingAsNotPending <~ SignalProducer.merge(lastStepFinished, onboardingAborted)
    }
    
    private lazy var stepViewController = OnboardingStepViewController(nibName: NSNib.Name(rawValue: "OnboardingStepViewController"), bundle: nil)
    private lazy var endedViewController = OnboardingEndedViewController(nibName: NSNib.Name(rawValue: "OnboardingEndedViewController"), bundle: nil)

    private lazy var stepPopover: NSPopover = {
        let popover = NSPopover()
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
    var onboardingTargetViews: [OnboardingStep.Identifier : SignalProducer<NSView, NoError>] { get }
}
