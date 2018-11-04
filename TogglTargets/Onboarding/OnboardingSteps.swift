//
//  OnboardingSteps.swift
//  TogglTargets
//
//  Created by David Dávila on 12.10.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

enum OnboardingStepIdentifier: String {
    case login
    case closeLogin
    case selectProject
    case createTimeTarget
    case setTargetHours
    case setWorkWeekdays
    case selectComputeStrategyFrom
    case seeTimeProgress
    case seeStrategy
    case seeDayProgress
}

private let StringsTableName = "OnboardingSteps"

private let OnboardingSteps: [OnboardingStep] = [
    OnboardingStep(identifier: .login,
                   text: NSLocalizedString("onboarding.step.login",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: login")),
    OnboardingStep(identifier: .closeLogin,
                   text: NSLocalizedString("onboarding.step.close-login",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: close login")),
    OnboardingStep(identifier: .selectProject,
                   text: NSLocalizedString("onboarding.step.select-project",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: select project")),
    OnboardingStep(identifier: .createTimeTarget,
                   text: NSLocalizedString("onboarding.step.create-time-target",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: create time target")),
    OnboardingStep(identifier: .setTargetHours,
                   text: NSLocalizedString("onboarding.step.set-target-hours",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: set target hours"),
                   allowContinue: true,
                   preferredEdge: .maxY),
    OnboardingStep(identifier: .setWorkWeekdays,
                   text: NSLocalizedString("onboarding.step.set-work-weekdays",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: set work weekdays"),
                   allowContinue: true),
    OnboardingStep(identifier: .selectComputeStrategyFrom,
                   text: NSLocalizedString("onboarding.step.select-compute-from",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: select from which day to compute the target strategy"), // swiftlint:disable:this line_length
                   allowContinue: true),
    OnboardingStep(identifier: .seeTimeProgress,
                   text: NSLocalizedString("onboarding.step.see-time-progress",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: see time progress"),
                   allowContinue: true),
    OnboardingStep(identifier: .seeStrategy,
                   text: NSLocalizedString("onboarding.step.see-strategy",
                                           tableName: StringsTableName,
                                           comment: "onboarding step: see strategy to reach time target"),
                   allowContinue: true),
    OnboardingStep(identifier: .seeDayProgress, text: NSLocalizedString("onboarding.step.see-day-progress",
                                                                        tableName: StringsTableName,
                                                                        comment: "onboarding step: see day progress"),
                   allowContinue: true)
]

func onboardingSteps(startingFrom initialStepIdentifier: OnboardingStepIdentifier? = nil) -> [OnboardingStep] {
    guard let initialStepIdentifier = initialStepIdentifier else {
        return OnboardingSteps
    }

    let foundIndex = OnboardingSteps.firstIndex { $0.identifier == initialStepIdentifier }!
    return [OnboardingStep](OnboardingSteps.suffix(from: foundIndex)) // TODO: return the slice instead of allocating new array?
}
