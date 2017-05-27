//
//  GoalProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class GoalProgressViewController: NSViewController {
    var timeFormatter: DateComponentsFormatter!
    
    var goalProgress: GoalProgress? {
        didSet {
            displayGoalProgress()
        }
    }
    
    @IBOutlet weak var totalWorkdaysLabel: NSTextField!
    @IBOutlet weak var remainingFullWorkdaysLabel: NSTextField!
    @IBOutlet weak var hoursWorkedLabel: NSTextField!
    @IBOutlet weak var hoursLeftLabel: NSTextField!
    
    @IBOutlet weak var workDaysProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var workHoursProgressIndicator: NSProgressIndicator!
    

    private func displayGoalProgress() {
        guard let progress = goalProgress else {
            return
        }
        
        totalWorkdaysLabel.integerValue = progress.totalWorkdays
        remainingFullWorkdaysLabel.integerValue = progress.remainingWorkdays

        workDaysProgressIndicator.maxValue = Double(progress.totalWorkdays)
        workDaysProgressIndicator.doubleValue = Double(progress.totalWorkdays - progress.remainingWorkdays)
        workHoursProgressIndicator.maxValue = progress.timeGoal
        workHoursProgressIndicator.doubleValue = progress.workedTime
        
        hoursWorkedLabel.stringValue = timeFormatter.string(from: progress.workedTime)!
        hoursLeftLabel.stringValue = timeFormatter.string(from: progress.remainingTimeToGoal)!
    }
}

class NoGoalProgressViewController: NSViewController {

}
