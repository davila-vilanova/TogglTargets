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
        case .errors(let count, let firstError):
            self.statusDescriptionLabel.stringValue = "Could Not Syncronize All Data"
            self.setStatusDetail((count == 1 ? firstError.shortDescriptionForUser : "\(count) syncing operations have errors"))
        case .success(let count):
            self.statusDescriptionLabel.stringValue = "All Data Synchronized"
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
    case errors(count: Int, first: APIAccessError)
    case success(count: Int)
    case idle
}

fileprivate func stateProducer(from statusesProducer: SignalProducer<[ActivityStatus], NoError>)
    -> SignalProducer<State, NoError> {
        let syncingCount = statusesProducer.map { $0.filter { $0.isExecuting } }.map { $0.count }
        let errorCountAndFirst = statusesProducer.map { $0.filter { $0.isError } }.map { ($0.count, $0.first?.error) }
        let successCount = statusesProducer.map { $0.filter { $0.isSuccessful } }.map { $0.count }

        return SignalProducer.combineLatest(syncingCount, successCount, errorCountAndFirst)
            .map { (syncingCount, successCount, errorCountAndFirst) in
                let (errorCount, firstError) = errorCountAndFirst
                if errorCount > 0 {
                    return .errors(count: errorCount, first: firstError!)
                } else if syncingCount > 0 {
                    return .syncing(count: syncingCount)
                } else if successCount > 0 {
                    return .success(count: successCount)
                } else {
                    return .idle
                }
        }
}

fileprivate extension APIAccessError {
    var shortDescriptionForUser: String {
        switch self {
        case .noCredentials:
            return "No credentials Configured"
        case .authenticationError(response: _):
            return "Authentication Error"
        case .loadingSubsystemError(underlyingError: let underlyingError):
            return underlyingError.localizedDescription
        case .serverHiccups(response: let response, data: _):
            return "Server Error (\(response.statusCode))"
        case .invalidJSON(underlyingError: _, data: _):
            return "Unexpected JSON in Response"
        case .nonHTTPResponseReceived(response: _):
            return "Unexpected Response Type"
        case .otherHTTPError(response: let response):
            return "HTTP error (\(response.statusCode))"
        }
    }
}
