//
//  DayProgressViewController.swift
//  TogglGoals
//
//  Created by David Davila on 27.05.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class DayProgressViewController: NSViewController {
    // MARK: - Outlets
    
    @IBOutlet weak var dayProgressBox: NSBox!
    @IBOutlet weak var todayProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var timeWorkedTodayLabel: NSTextField!
    @IBOutlet weak var timeRemainingToWorkTodayLabel: NSTextField!
    
    // MARK: - 
    
    var timeFormatter: DateComponentsFormatter!
    
    var dayProgress: DayProgress? {
        didSet {
            displayDayProgress()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayDayProgress()
    }
    
    func displayDayProgress() {
        guard isViewLoaded,
            let dayProgress = self.dayProgress else {
                return
        }
        
        let formattedTimeWorkedToday = timeFormatter.string(from: dayProgress.workedTimeToday)!
        timeWorkedTodayLabel.stringValue = "\(formattedTimeWorkedToday) worked today"
        
        if let remaining = dayProgress.remainingTimeToDayBaselineToday {
            timeRemainingToWorkTodayLabel.isHidden = false
            let formattedTimeRemainingToWorkToday = timeFormatter.string(from: remaining)!
            timeRemainingToWorkTodayLabel.stringValue = "\(formattedTimeRemainingToWorkToday) left to meet your goal today"
            todayProgressIndicator.isIndeterminate = false
            todayProgressIndicator.maxValue = dayProgress.workedTimeToday + remaining
            todayProgressIndicator.doubleValue = dayProgress.workedTimeToday
        } else {
            timeRemainingToWorkTodayLabel.isHidden = true
            todayProgressIndicator.isIndeterminate = true
        }
    }
}
