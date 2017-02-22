//
//  ProjectCollectionViewItem.swift
//  TogglGoals
//
//  Created by David Davila on 22/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectCollectionViewItem: NSCollectionViewItem
{
    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!

    var projectName: String? {
        didSet {
            if isViewLoaded {
                let value: String
                if let name = projectName {
                    value = name
                } else {
                    value = "---"
                }
                projectNameLabel.stringValue = value
            }
        }
    }

    private var observedGoalProperty: ObservedProperty<TimeGoal>?
    internal var goalProperty: Property<TimeGoal>? {
        set {
            if let p = newValue {
                observedGoalProperty =
                    ObservedProperty(original: p,
                                     valueObserver: {[weak self] (goal) in
                                        self?.updateGoalLabel(goal: goal)
                    },
                                     invalidationObserver: {

                    })
                updateGoalLabel(goal:p.value)
            } else {
                observedGoalProperty?.unobserve()
            }
        }
        get {
            return observedGoalProperty?.original
        }
    }

    private var observedReportProperty: ObservedProperty<TimeReport>?
    internal var reportProperty: Property<TimeReport>? {
        set {
            if let p = newValue {
                observedReportProperty =
                    ObservedProperty(original: p,
                                     valueObserver: {[weak self] (report) in
                                        self?.updateReportLabel(report: report)
                    },
                                     invalidationObserver: {

                    })
                updateReportLabel(report: p.value)
            } else {
                observedReportProperty?.unobserve()
            }
        }
        get {
            return observedReportProperty?.original
        }
    }

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

    override func viewDidLoad() {
        super.viewDidLoad()
        if let name = projectName {
            projectNameLabel.stringValue = name
        }
        updateGoalLabel(goal: goalProperty?.value)
    }

    private func updateGoalLabel(goal: TimeGoal?) {
        guard isViewLoaded else {
            return
        }
        let newStringValue: String
        if let g = goal {
            newStringValue = "\(g.hoursPerMonth) hours per month"
        } else {
            newStringValue = "(no goal)"
        }

        DispatchQueue.main.async { [weak self, newStringValue] in
            self?.goalLabel.stringValue = newStringValue
        }
    }

    private func updateReportLabel(report: TimeReport?) {
        guard isViewLoaded else {
            return
        }
        let newStringValue: String
        if let r = report {
            let hours = r.workedTime / 3600
            newStringValue = String.init(format: "%.2f hours worked", hours)
        } else {
            newStringValue = "Zero hours worked"
        }

        DispatchQueue.main.async { [weak self, newStringValue] in
            self?.reportLabel.stringValue = newStringValue
        }
    }
}
