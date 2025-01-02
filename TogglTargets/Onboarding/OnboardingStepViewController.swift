//
//  OnboardingStepViewController.swift
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
import ReactiveCocoa

class OnboardingStepViewController: NSViewController {

    @IBOutlet weak var stepDescriptionField: NSTextField!
    @IBOutlet weak var moveOnToNextStepButton: NSButton!
    @IBOutlet weak var stopOnboardingButton: NSButton!

    var representedStep: BindingTarget<OnboardingStep> {
        return currentStep.deoptionalizedBindingTarget
    }

    var requestAbortOnboarding: SignalProducer<Void, Never> {
        return stopPressed.values.producer
    }

    var moveOnToNextStep: SignalProducer<OnboardingStepIdentifier, Never> {
        return currentStep.producer.sample(on: moveOnPressed.values).compactMap { $0?.identifier }
    }

    var configureForLastStep: BindingTarget<Void> {
        return lastStepTrigger.deoptionalizedBindingTarget
    }

    private let currentStep = MutableProperty<OnboardingStep?>(nil)
    private let moveOnPressed = Action<Void, Void, Never> { SignalProducer(value: ()) }
    private let stopPressed = Action<Void, Void, Never> { SignalProducer(value: ()) }
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
            <~ lastStepTrigger.map { _ in
                NSLocalizedString("onboarding.close-after-completion",
                                  tableName: "OnboardingStepViewController",
                                  comment: "onboarding: close after completion")
        }

        stopOnboardingButton.reactive.makeBindingTarget { $0.isEnabled = $1 } <~ lastStepTrigger.map { _ in false }
        stopOnboardingButton.reactive.makeBindingTarget { button, title in button.title = title }
            <~ lastStepTrigger.map { _ in
                NSLocalizedString("onboarding.thank-you",
                                  tableName: "OnboardingStepViewController",
                                  comment: "onboarding: small thank you note")
        }
    }
}
