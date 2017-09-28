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
import Result

class ProjectCollectionViewItem: NSCollectionViewItem {

    // MARK: - Outlets

    @IBOutlet weak var projectNameLabel: NSTextField!
    @IBOutlet weak var goalLabel: NSTextField!
    @IBOutlet weak var reportLabel: NSTextField!


    // MARK: - Project

    internal var currentProject: Project? {
        set {
            project.value = newValue
        }
        get {
            return project.value
        }
    }


    // MARK: - Exposed targets

    internal var goals: BindingTarget<Property<Goal?>?> { return _goals.bindingTarget }
    internal var reports: BindingTarget<Property<TwoPartTimeReport?>?> { return _reports.bindingTarget }


    // MARK: - Backing properties

    private let _goals = MutableProperty<Property<Goal?>?>(nil)
    private let _reports = MutableProperty<Property<TwoPartTimeReport?>?>(nil)


    // MARK: - Selection of latest binding

    private var project = MutableProperty<Project?>(nil)
    private lazy var goal: SignalProducer<Goal?, NoError> = _goals.producer.skipNil().flatten(.latest)
    private lazy var report: SignalProducer<TwoPartTimeReport?, NoError> = _reports.producer.skipNil().flatten(.latest)


    // MARK: - NSCollectionViewItem

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

        projectNameLabel.reactive.text <~ project.map { project -> String in
            return project?.name ?? "(nothing)"
        }

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
