//
//  OnboardingGuide.swift
//  TogglTargets
//
//  Created by David Dávila on 03.10.18.
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

/// Key for the value stored in the user defaults to keep track of whether onboarding is pending.
private let onboardingNotPendingKey = "OnboardingNotPending"

/// Represents a step in the visited tour of the app.
struct OnboardingStep {

    /// The identifier associated to this step.
    let identifier: OnboardingStepIdentifier

    /// The user-facing text that will be displayed while this step is active in the onboarding process.
    let text: String

    /// Whether the user should be able to move on to the next step without first performing an action in the app.
    let allowContinue: Bool

    /// The preferred edge for displaying the popover window that shows the step.
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

/// Coordinates the onboarding process.
/// * Shows each onboarding step popover in order, discarding it when the user peforms the corresponding action or,
///   if the step allows, when the user decides to move on to the next step.
/// * Marks the onboarding process as complete when the user completes all the steps or deliberately aborts the process.
/// * Allows for checking the completion status of the onboarding process.
/// * Notifies when an ongoing onboarding process is completed.
class OnboardingGuide {
    var lifetime: Lifetime
    private let token: Lifetime.Token

    /// Sends an empty value whenever the onboarding process has ended, either by completing all the steps or by
    /// the user deliberately aborting the process.
    var onboardingEnded: SignalProducer<Void, Never> {
        return _onboardingEnded.producer.skipNil()
    }

    /// Backs the value of the `onboardingEnded` producer.
    private let _onboardingEnded = MutableProperty<Void?>(nil)

    /// An ordered collection of all the onboarding steps to show during this onboarding process.
    private let steps: [OnboardingStep]

    /// Maps each onboarding step's identifier to the view to which the step will point.
    /// The view is wrapped in a mutable property to make it convenient to start listening to the view before it is
    /// registered by another part of the app.
    /// The view is stored as a materialized signal. Termination events indicate that the action associated with this
    /// view's step is completed and the onboarding process can move on.
    private lazy var
    targetViewEventHolders: [OnboardingStepIdentifier: MutableProperty<Signal<NSView, Never>.Event?>] = {
        var holders =
            [OnboardingStepIdentifier: MutableProperty<Signal<NSView, Never>.Event?>](minimumCapacity: steps.count)
        for step in steps {
            holders[step.identifier] = MutableProperty<Signal<NSView, Never>.Event?>(nil)
        }
        return holders
    }()

    /// A collection of views associated with each of the onboarding steps, ordered by each step's relative order in
    /// the onboarding process.
    /// Each view is wrapped in a mutable property to make it convenient to start listening to the view before it is
    /// registered by another part of the app.
    /// The view is stored as a materialized signal. Termination events indicate that the action associated with this
    /// view's step is completed and the onboarding process can move on.
    private lazy var sortedTargetViewEventHolders: [MutableProperty<Signal<NSView, Never>.Event?>] = {
       var sorted = [MutableProperty<Signal<NSView, Never>.Event?>]()
        for step in steps {
            guard let holder = targetViewEventHolders[step.identifier] else {
                assert(false)
                continue
            }
            sorted.append(holder)
        }
        return sorted
    }()

    /// Accepts providers of views that are associated with steps in the app's onboarding sequence.
    ///
    /// - parameters:
    ///   - registree: Any entity. It will be determined at runtime if it conforms to the
    ///                `OnboardingTargetViewsProvider` protocol and, if it does, the views it provides will be
    ///                associated with the corresponding onboarding steps. If it does not, this call will be ignored.
    func register(_ registree: Any) {
        func connect(_ viewProducer: SignalProducer<NSView, Never>,
                     toViewHolderFor stepIdentifier: OnboardingStepIdentifier) {
            func take(from viewProducer: SignalProducer<NSView, Never>, stepIdentifier: OnboardingStepIdentifier)
                -> SignalProducer<Signal<NSView, Never>.Event, Never> {
                    func moveOnButtonPressed(for stepId: OnboardingStepIdentifier) -> SignalProducer<Void, Never> {
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

    /// Initializes a new instance with the provided onboarding steps and user defaults. Starts the onboarding process.
    ///
    /// - parameters:
    ///   - steps: An ordered collection of the steps of which the onboarding sequence will consist.
    ///   - defaults: The user defaults in which to record the onboarding completed status once the onboarding process
    ///               is completed.
    init(steps: [OnboardingStep], defaults: UserDefaults) { // swiftlint:disable:this function_body_length
        assert(!steps.isEmpty)
        self.steps = steps

        (lifetime, token) = Lifetime.make()

        func extractViewProducer(_ prop: MutableProperty<Signal<NSView, Never>.Event?>)
            -> SignalProducer<NSView, Never> {
                return prop.producer.skipNil().dematerialize()
        }

        // Producer that sends the view associated with first onboarding step and then all successive ones once the
        // previous view has terminated. The previous view should complete whenever the user performs the action
        // associated with that step.
        let views = SignalProducer(sortedTargetViewEventHolders)
            .map(extractViewProducer)
            .flatten(.concat)

        // Same as views but it wont send a view value until its corresponding window is available.
        // This is useful because showing a popover for a view that is not attached to a window raises an exception.
        let windowAttachedViews = views.zip(with:
            views.map {
                $0.reactive.producer(forKeyPath: "window")
                .skipNil().compactMap { $0 as? NSWindow }
                    .take(first: 1)
                }
                .flatten(.concat))
            .map { $0.0 }

        // Sends an empty value every time a view associated with the onboarding sequence terminates, but it only
        // sends the termination event for a given view if all the views that come before it have already terminated.
        let sortedViewTerminations = SignalProducer(sortedTargetViewEventHolders)
            .map {
                $0.producer.skipNil()
                    .filter { $0.isTerminating }
                    .map { _ in () }
                    .take(first: 1)
            }
            .flatten(.concat)

        // Sends an empty value if and when the user requests to terminate the onboarding sequence before completed.
        let abortOnboardingRequested = stepViewController.requestAbortOnboarding

        // Sends an onboarding step together with its corresponding view whenever the previous steps have completed and
        // the view has become available.
        let pacedSteps = SignalProducer(steps).zip(with: windowAttachedViews).take(until: abortOnboardingRequested)

        let lastStepStarted = pacedSteps.materialize().filter { $0.isCompleted }.map { _ in () }
        let lastStepShown = lastStepStarted.take(first: 1).then(stepPopoverDelegate.popoverDidShowTrigger.producer)
        let lastStepClosed = lastStepShown.take(first: 1).then(stepPopoverDelegate.popoverDidCloseTrigger.producer)

        // Onboarding ends when the sequence completes or when it is aborted.
        let onboardingEnded = SignalProducer.merge(abortOnboardingRequested, lastStepClosed)

        // Shows the onboarding step popover taking into consideration the edge to which the popover should prefer to be
        // anchored.
        let showPopover: BindingTarget<(NSView, NSRectEdge)> = stepPopover.reactive.makeBindingTarget { (pop, target) in
            let (view, edge) = target
            pop.show(relativeTo: view.bounds, of: view, preferredEdge: edge)
        }

        // Closes the onboarding step popover.
        let closePopover: BindingTarget<Void> = stepPopover.reactive.makeBindingTarget { pop, _ in pop.close() }

        // Close the popover whenever the current view terminates or the user aborts the sequence, show it whenever
        // the next step has become available. Connect the close action before the open action so that the popover is
        // closed (if it is open) before it opens, instead of it closing right after opening.
        closePopover <~ SignalProducer.merge(sortedViewTerminations, abortOnboardingRequested)
        showPopover <~ pacedSteps.map { step, view in (view, step.preferredEdge) }

        // Send each step to the step popover whenever the step becomes available but synchronize it so that it updates
        // its contents while in the closed state.
        stepViewController.representedStep <~
            pacedSteps.zip(with: stepPopoverDelegate.popoverDidCloseTrigger.producer.prefix(value: ())).map { $0.0.0 }

        // Reconfigure the step popover's views upon arrival to the last step of the onboarding sequence.
        stepViewController.configureForLastStep <~ lastStepStarted

        // Mark onboarding as not pending in the user defaults
        let markOnboardingAsNotPending: BindingTarget<Void> = defaults.reactive.makeBindingTarget { defaults, _ in
            defaults.set(true, forKey: onboardingNotPendingKey)
        }

        // Onboarding is not pending once it ends (be it by completing or by aborting the sequence.)
        markOnboardingAsNotPending <~ onboardingEnded

        // Publish onboarding ended to consumers.
        _onboardingEnded <~ onboardingEnded
    }

    /// The popover to anchor to each of the onboarding views in succession as the sequence progresses.
    private lazy var stepPopover: NSPopover = {
        let popover = NSPopover()
        popover.contentViewController = stepViewController
        popover.behavior = .applicationDefined
        popover.delegate = stepPopoverDelegate
        return popover
    }()

    /// A delegate to `stepPopover` that will forward the didShow and didClose events.
    private lazy var stepPopoverDelegate = PopoverDelegate() // swiftlint:disable:this weak_delegate

    /// The view controller that manages the views in `stepPopover`.
    private lazy var stepViewController =
        OnboardingStepViewController(nibName: "OnboardingStepViewController", bundle: nil)

    /// Determines whether the user should undergo onboarding based on the information stored in the user defaults.
    ///
    /// - parameters:
    ///   - defaults: An instance of user defaults to check if the user did already complete or abort onboarding
    ///               previously. Pass the same instance of user defaults to this method and to the initializer when
    ///               starting onboarding.
    ///
    /// - returns: True if the onboarding process should start, false otherwise.
    static func shouldOnboard(_ defaults: UserDefaults) -> Bool {
        return !defaults.bool(forKey: onboardingNotPendingKey)
    }
}

/// An entity, typically a view controller, that can supply any views involved with the onboarding sequence alongside
/// their corresponding step IDs. The onboarding step popover will be anchored to each of the views in the order in
/// which the onboarding steps are defined.
protocol OnboardingTargetViewsProvider {

    /// A dictionary whose keys are onboarding step identifiers and values are the producers that emit the view
    /// associated with the corresponding step when it (the view) becomes available, and terminate whenever the user
    /// action associated with the step is performed and the onboarding sequence can continue on to the next
    /// step.
    var onboardingTargetViews: [OnboardingStepIdentifier: SignalProducer<NSView, Never>] { get }
}

/// Can be set as the delegate of an `NSPopover` to forward its didShow and didClose events.
private class PopoverDelegate: NSObject, NSPopoverDelegate {
    private let _popoverDidShowTrigger = MutableProperty<Void?>(nil)
    private let _popoverDidCloseTrigger = MutableProperty<Void?>(nil)

    /// Sends an empty value every time the popover is shown.
    var popoverDidShowTrigger: Signal<Void, Never> {
        return _popoverDidShowTrigger.signal.skipNil()
    }

    /// Sends an empty value every time the popover is closed.
    var popoverDidCloseTrigger: Signal<Void, Never> {
        return _popoverDidCloseTrigger.signal.skipNil()
    }

    func popoverDidShow(_ notification: Notification) {
        _popoverDidShowTrigger.value = ()
    }

    func popoverDidClose(_ notification: Notification) {
        _popoverDidCloseTrigger.value = ()
    }
}
