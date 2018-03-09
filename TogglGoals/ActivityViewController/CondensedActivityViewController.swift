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

    func connectInputs(activityStatuses: SignalProducer<[ActivityStatus], NoError>) {
        self.activityStatuses <~ activityStatuses
    }

    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var resultImageView: NSImageView!
    @IBOutlet weak var statusDescriptionLabel: NSTextField!
    @IBOutlet weak var statusDetailLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        displayState <~ stateProducer(from: activityStatuses.producer)
    }

    private let (lifetime, token) = Lifetime.make()
    private lazy var displayState = BindingTarget<State>(on: UIScheduler(), lifetime: lifetime) { [unowned self] in
        switch $0 {
        case .syncing(let count):
            self.resultImageView.isHidden = true
            self.progressIndicator.isHidden = false
            self.statusDescriptionLabel.stringValue = "Syncing..."
            self.statusDetailLabel.stringValue = "\(count) syncing \(count == 1 ? "activity" : "activities") in progress"
            self.statusDetailLabel.isHidden = false
        case .errors(let count):
            self.progressIndicator.isHidden = true
            self.resultImageView.isHidden = false
            self.resultImageView.image = NSImage(named: NSImage.Name("NSCaution"))!
            self.statusDescriptionLabel.stringValue = (count == 1 ? "Error" : "Errors") + " syncing data"
            self.statusDetailLabel.stringValue = (count == 1 ? "An error" : "\(count) errors")
                + " occurred - click for details"
            self.statusDetailLabel.isHidden = false
        case .success(let count):
            self.progressIndicator.isHidden = true
            self.resultImageView.isHidden = false
            self.statusDescriptionLabel.stringValue = "All data synchronized"
            self.resultImageView.image = NSImage(named: NSImage.Name("NSNetwork"))!
            self.statusDetailLabel.isHidden = true
        case .idle:
            break
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
