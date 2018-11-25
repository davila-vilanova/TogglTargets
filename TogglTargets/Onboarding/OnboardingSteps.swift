//
//  OnboardingSteps.swift
//  TogglTargets
//
//  Created by David Dávila on 12.10.18.
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

/// The identifiers for each of the defined onboarding steps.
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

/// Name of the strings table in which the localized step descriptions are defined.
private let stringsTableName = "OnboardingSteps"

/// All the onboarding steps defined in order.
private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(identifier: .login,
                   text: NSLocalizedString("onboarding.step.login",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: login")),
    OnboardingStep(identifier: .closeLogin,
                   text: NSLocalizedString("onboarding.step.close-login",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: close login")),
    OnboardingStep(identifier: .selectProject,
                   text: NSLocalizedString("onboarding.step.select-project",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: select project")),
    OnboardingStep(identifier: .createTimeTarget,
                   text: NSLocalizedString("onboarding.step.create-time-target",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: create time target")),
    OnboardingStep(identifier: .setTargetHours,
                   text: NSLocalizedString("onboarding.step.set-target-hours",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: set target hours"),
                   allowContinue: true,
                   preferredEdge: .maxY),
    OnboardingStep(identifier: .setWorkWeekdays,
                   text: NSLocalizedString("onboarding.step.set-work-weekdays",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: set work weekdays"),
                   allowContinue: true),
    OnboardingStep(identifier: .selectComputeStrategyFrom,
                   text: NSLocalizedString("onboarding.step.select-compute-from",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: select from which day to compute the target strategy"), // swiftlint:disable:this line_length
                   allowContinue: true),
    OnboardingStep(identifier: .seeTimeProgress,
                   text: NSLocalizedString("onboarding.step.see-time-progress",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: see time progress"),
                   allowContinue: true),
    OnboardingStep(identifier: .seeStrategy,
                   text: NSLocalizedString("onboarding.step.see-strategy",
                                           tableName: stringsTableName,
                                           comment: "onboarding step: see strategy to reach time target"),
                   allowContinue: true),
    OnboardingStep(identifier: .seeDayProgress, text: NSLocalizedString("onboarding.step.see-day-progress",
                                                                        tableName: stringsTableName,
                                                                        comment: "onboarding step: see day progress"),
                   allowContinue: true)
]

/// Returns the onboarding steps in order, starting from the beginning or from the step whose identifier is provided.
///
/// - parameters:
///   - initialStepIdentifier: The identifier corresponding to the step from which to start the onboarding, or `nil` to
///                            start from the first defined step. The default value is `nil`.
///
/// - returns: An array of steps in the defined order, starting from the first step or from the step whose identifier
///            was provided as `initialStepIdentifier`.
func onboardingSteps(startingFrom initialStepIdentifier: OnboardingStepIdentifier? = nil) -> [OnboardingStep] {
    guard let initialStepIdentifier = initialStepIdentifier else {
        return onboardingSteps
    }

    let foundIndex = onboardingSteps.firstIndex { $0.identifier == initialStepIdentifier }!

    // TODO: return the slice instead of allocating new array?
    return [OnboardingStep](onboardingSteps.suffix(from: foundIndex))
}
