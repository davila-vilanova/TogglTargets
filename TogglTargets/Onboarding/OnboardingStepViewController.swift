//
//  OnboardingStepViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 03.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class OnboardingStepViewController: NSViewController {

    @IBOutlet weak var stepDescriptionField: NSTextField!
    @IBOutlet weak var moveOnToNextStepButton: NSButton!
    @IBOutlet weak var stopOnboardingButton: NSButton!

    var representedStep: BindingTarget<OnboardingStep> {
        return currentStep.deoptionalizedBindingTarget
    }

    var requestAbortOnboarding: SignalProducer<Void, NoError> {
        return stopPressed.values.producer
    }

    var moveOnToNextStep: SignalProducer<OnboardingStepIdentifier, NoError> {
        return currentStep.producer.sample(on: moveOnPressed.values).filterMap { $0?.identifier }
    }

    var configureForLastStep: BindingTarget<Void> {
        return lastStepTrigger.deoptionalizedBindingTarget
    }

    private let currentStep = MutableProperty<OnboardingStep?>(nil)
    private let moveOnPressed = Action<Void, Void, NoError> { SignalProducer(value: ()) }
    private let stopPressed = Action<Void, Void, NoError> { SignalProducer(value: ()) }
    private let lastStepTrigger = MutableProperty<Void?>(nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        stepDescriptionField.reactive.text <~ currentStep.producer.skipNil().map { $0.text }
        moveOnToNextStepButton.reactive.pressed = CocoaAction(moveOnPressed)
        stopOnboardingButton.reactive.pressed = CocoaAction(stopPressed)

        let lastStepTrigger = self.lastStepTrigger.producer.skipNil()

        let hideMoveOnButton: BindingTarget<Bool> = moveOnToNextStepButton.reactive.makeBindingTarget {
            $0.isHidden = $1
            $0.isEnabled = !$1
        }
        hideMoveOnButton <~ currentStep.producer.skipNil().map { $0.allowContinue }.negate()
        hideMoveOnButton <~ lastStepTrigger.map { _ in false }

        moveOnToNextStepButton.reactive.makeBindingTarget { button, title in button.title = title }
            <~ lastStepTrigger.map { _ in NSLocalizedString("onboarding.close-after-completion", tableName: "OnboardingStepViewController", comment: "onboarding: close after completion") }

        stopOnboardingButton.reactive.makeBindingTarget { $0.isEnabled = $1 } <~ lastStepTrigger.map { _ in false }
        stopOnboardingButton.reactive.makeBindingTarget { button, title in button.title = title }
            <~ lastStepTrigger.map { _ in NSLocalizedString("onboarding.thank-you", tableName: "OnboardingStepViewController", comment: "onboarding: small thank you note") }
    }
}
