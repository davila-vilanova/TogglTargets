//
//  GoalCreatingDeleting.swift
//  TogglTargets
//
//  Created by David Dávila on 03.09.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

@objc protocol GoalCreatingDeleting: NSUserInterfaceValidations {
    func createGoal(_ sender: Any?)
    func deleteGoal(_ sender: Any?)
}
