//
//  ProjectCollectionViewItem.swift
//  TogglGoals
//
//  Created by David Davila on 22/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class ProjectCollectionViewItem: NSCollectionViewItem {

    private var goal = MutableProperty<TimeGoal?>(nil)
    private var report = MutableProperty<TwoPartTimeReport?>(nil)

    internal func bindExclusivelyTo(project: Project?,
                                    goal: MutableProperty<TimeGoal?>,
                                    report: MutableProperty<TwoPartTimeReport?>) {
        bindingDisposables.disposeAll()

        projectNameLabel.stringValue = project?.name ?? "(no name)"
        bindingDisposables.put(self.goal <~ goal)
        bindingDisposables.put(self.report <~ report)
    }

    private var bindingDisposables = DisposableBag()

    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!

    override var textField: NSTextField? {
        get {
            return projectNameLabel
        }
        set { }
    }

    override var isSelected: Bool {
        set {
            let selected = newValue
            super.isSelected = selected

            let color = selected ? NSColor.controlHighlightColor : NSColor.clear
            self.view.layer?.backgroundColor = color.cgColor
        }

        get {
            return super.isSelected
        }
    }

    private lazy var timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        f.unitsStyle = .full
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        goalLabel.reactive.text <~ goal.map { goal -> String in
            if let goal = goal {
                return "\(goal.hoursPerMonth) hours per month"
            } else {
                return "(no goal)"
            }
        }
        reportLabel.reactive.text <~ report.map { [timeFormatter] report -> String in
            if let report = report {
                return "\(timeFormatter.string(from: report.workedTime) ?? "[unknown]") worked"
            } else {
                return "Zero hours worked"
            }
        }
    }
}
