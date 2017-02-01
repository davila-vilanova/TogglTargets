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
        if let g = goal {
            if let hours = g.hoursPerMonth {
                goalLabel.stringValue = "\(hours) hours per month"
            } else {
                goalLabel.stringValue = "? hours per month"
            }
        } else {
            goalLabel.stringValue = "(no goal)"
        }
    }
}
