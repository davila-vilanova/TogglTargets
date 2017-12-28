//
//  ActivityViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 28.12.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class ActivityViewController: NSViewController {

    internal func connectInputs(activities: SignalProducer<Set<RetrievalActivity>, NoError>) {
        runningActivities <~ activities
    }

    private let runningActivities = MutableProperty(Set<RetrievalActivity>())

    @IBOutlet weak var label: NSTextField!

    private let (lifetime, token) = Lifetime.make()

    private lazy var display = BindingTarget(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
        self.label.animator().isHidden = false
    }

    private lazy var hide = BindingTarget(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
        self.label.animator().isHidden = true
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        label.isHidden = true

        display <~ runningActivities.producer.filter { !$0.isEmpty }.map { _ in () }
        hide <~ runningActivities.producer.filter { $0.isEmpty }.map { _ in () }


        label.reactive.text <~ runningActivities.producer.filter { !$0.isEmpty }.map {
            switch $0 {
            case Set([RetrievalActivity.profile]): return "retrieving profile"
            case Set<RetrievalActivity>([.projects, .reports]): return "retrieving projects and reports"
            case Set([RetrievalActivity.projects]): return "retrieving projects"
            case Set([RetrievalActivity.reports]): return "retrieving reports"
            case Set([RetrievalActivity.runningEntry]): return "retrieving currently running entry"
            default: return "retrieving data"
            }
        }
    }
}

