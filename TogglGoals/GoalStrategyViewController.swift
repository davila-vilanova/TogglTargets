//
//  GoalStrategyViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class GoalStrategyViewController: NSViewController {
    
    // MARK: - Outlets

    @IBOutlet weak var totalHoursStrategyLabel: NSTextField!
    @IBOutlet weak var hoursPerDayLabel: NSTextField!
    @IBOutlet weak var baselineDifferentialLabel: NSTextField!


    // MARK: - Value formatters
    
    var timeFormatter: DateComponentsFormatter!
    var percentFormatter: NumberFormatter!
    
    // MARK: - Represented data
    
    var goalStrategy: GoalStrategy? {
        didSet {
            if let strategy = goalStrategy {
                totalHoursStrategyLabel.stringValue = timeFormatter.string(from: strategy.timeGoal)!
                hoursPerDayLabel.stringValue = timeFormatter.string(from: strategy.dayBaselineAdjustedToProgress)!

                let dayBaseline = timeFormatter.string(from: strategy.dayBaseline)!
                let dayBaselineDifferential = strategy.dayBaselineDifferential
                let absoluteBaselineDifferential = abs(dayBaselineDifferential)
                
                let baselineDifferentialText: String
                
                if absoluteBaselineDifferential < 0.01 {
                    baselineDifferentialText = "That prety much matches your baseline of \(dayBaseline)"
                } else {
                    let formattedBaselineDifferential = percentFormatter.string(from: NSNumber(value: abs(dayBaselineDifferential)))!
                    if dayBaselineDifferential > 0 {
                        baselineDifferentialText = "That is \(formattedBaselineDifferential) more than your baseline of \(dayBaseline)"
                    } else {
                        baselineDifferentialText = "That is \(formattedBaselineDifferential) less than your baseline of \(dayBaseline)"
                    }
                }
                
                baselineDifferentialLabel.stringValue = baselineDifferentialText
            }
        }
    }
    
    // MARK : -
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
