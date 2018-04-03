//
//  CondensedActivityViewController.swift
//  TogglGoals
//
//  Created by David Dávila on 09.03.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

class CondensedActivityViewController: NSViewController {
    private let activityStatuses = MutableProperty([ActivityStatus]())
    private let requestExpandDetails = MutableProperty(false)

    func connectInterface(activityStatuses: SignalProducer<[ActivityStatus], NoError>,
                          expandDetails: BindingTarget<Bool>) {
        enforceOnce(for: "CondensedActivityViewController.connectInterface()") { [unowned self] in
            self.activityStatuses <~ activityStatuses
            expandDetails <~ self.requestExpandDetails
        }
    }

    @IBOutlet weak var statusDescriptionLabel: NSTextField!
    @IBOutlet weak var statusDetailLabel: NSTextField!
    @IBOutlet weak var horizontalLine: NSBox!

    override func viewDidLoad() {
        super.viewDidLoad()
        displayState <~ stateProducer(from: activityStatuses.producer)
        horizontalLine.reactive.makeBindingTarget { $0.animator().isHidden = !$1 } <~ requestExpandDetails
    }

    @IBAction func expandDetails(_ sender: Any) {
        requestExpandDetails.value = !requestExpandDetails.value
    }

    private weak var statusDescriptionTopConstraint: NSLayoutConstraint?
    private weak var statusDescriptionCenterYConstraint: NSLayoutConstraint?

    private let (lifetime, token) = Lifetime.make()
    private lazy var displayState = BindingTarget<State>(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
        switch $0 {
        case .syncing(let count):
            self.statusDescriptionLabel.stringValue = "Syncing..."
            self.setStatusDetail("\(count) syncing \(count == 1 ? "activity" : "activities") in progress")
        case .errors(let count):
            self.statusDescriptionLabel.stringValue = (count == 1 ? "Error" : "Errors") + " syncing data"
            self.setStatusDetail((count == 1 ? "An error" : "\(count) errors") + " occurred.")
        case .success(let count):
            self.statusDescriptionLabel.stringValue = "All data synchronized"
            self.setStatusDetail(nil)
        case .idle:
            break
        }
    }

    private func setStatusDetail(_ text: String?) {
        if let text = text {
            statusDetailLabel.isHidden = false
            statusDetailLabel.stringValue = text
            statusDescriptionCenterYConstraint?.isActive = false

            if statusDescriptionTopConstraint == nil {
                let topConstraint = statusDescriptionLabel
                    .topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
                topConstraint.isActive = true
                statusDescriptionTopConstraint = topConstraint
            }
        } else {
            statusDetailLabel.isHidden = true
            statusDescriptionTopConstraint?.isActive = false
            if statusDescriptionCenterYConstraint == nil {
                let centerYConstraint = statusDescriptionLabel
                    .centerYAnchor.constraint(equalTo: view.centerYAnchor)
                centerYConstraint.isActive = true
                statusDescriptionCenterYConstraint = centerYConstraint
            }
        }
    }
}

fileprivate enum State {
    case syncing(count: Int)
    case errors(count: Int)
    case success(count: Int)
    case idle
}

fileprivate func stateProducer(from statusesProducer: SignalProducer<[ActivityStatus], NoError>)
    -> SignalProducer<State, NoError> {
        let syncingCount = statusesProducer.map { $0.filter { $0.isExecuting } }.map { $0.count }
        let errorCount = statusesProducer.map { $0.filter { $0.isError } }.map { $0.count }
        let successCount = statusesProducer.map { $0.filter { $0.isSuccessful } }.map { $0.count }

        return SignalProducer.combineLatest(syncingCount, errorCount, successCount)
            .map { (syncingCount, errorCount, successCount) in
                if errorCount > 0 {
                    return .errors(count: errorCount)
                } else if syncingCount > 0 {
                    return .syncing(count: syncingCount)
                } else if successCount > 0 {
                    return .success(count: successCount)
                } else {
                    return .idle
                }
        }
}
