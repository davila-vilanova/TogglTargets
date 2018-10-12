//
//  OnboardingSteps.swift
//  TogglGoals
//
//  Created by David Dávila on 12.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

enum OnboardingStepIdentifier: String {
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

let OnboardingSteps: [OnboardingStep] = [
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
