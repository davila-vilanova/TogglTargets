//
//  OnboardingStepViewController.swift
//  TogglGoals
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

    var stopOnboarding: SignalProducer<Void, NoError> {
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

        let hideMoveOnButton = moveOnToNextStepButton.reactive.makeBindingTarget { $0.isHidden = $1 }
        hideMoveOnButton <~ currentStep.producer.skipNil().map { $0.allowContinue }.negate()
        
        hideMoveOnButton <~ lastStepTrigger.producer.skipNil().map { _ in false }
        moveOnToNextStepButton.reactive.makeBindingTarget { button, _ in
            button.title = NSLocalizedString("onboarding.step.close-after-completion", comment: "onboarding: close after completion")
        } as BindingTarget<Void> <~ lastStepTrigger.producer.skipNil()
        stopOnboardingButton.reactive.makeBindingTarget { $0.isHidden = $1 } <~ lastStepTrigger.producer.skipNil().map { _ in true }
    }

    override func viewWillAppear() {
        view.window!.initialFirstResponder = moveOnToNextStepButton
    }
}
