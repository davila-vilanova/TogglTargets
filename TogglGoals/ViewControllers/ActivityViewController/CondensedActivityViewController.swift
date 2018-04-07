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
    private let (lifetime, token) = Lifetime.make()

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
    @IBOutlet weak var toggleRequestExpandedDetailsGestureRecognizer: NSClickGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        horizontalLine.reactive.makeBindingTarget { $0.animator().isHidden = !$1 } <~ requestExpandDetails

        let stateProducer = makeStateProducer(from: activityStatuses.producer)
        let syncingStates = stateProducer.filter(State.isSyncing)
        let errorStates = stateProducer.filter(State.isErrors)
        let singleErrorStates = errorStates.filter(State.hasSingleItem)
        let multipleErrorStates = errorStates.filter(State.hasMultipleItems)
        let successStates = stateProducer.filter(State.isSuccess)
        let idleStates = stateProducer.filter(State.isIdle)

        statusDescriptionLabel.reactive.text <~ SignalProducer.merge(
            syncingStates.map { _ in "Syncing..."},
            errorStates.map { _ in "Could Not Syncronize All Data" },
            successStates.map { _ in "All Data Synchronized" }
        )

        statusDetailLabel.reactive.text <~ SignalProducer.merge(
            syncingStates.map(State.getCount).map { (count: Int) in "\(count) syncing \(count == 1 ? "operation" : "operations") in progress" },
            singleErrorStates.map(State.firstError).map(APIAccessError.shortDescriptionForUser),
            multipleErrorStates.map(State.getCount).map { "\($0) syncing operations have errors" }
        )

        let showStatusDetail = SignalProducer.merge(
            syncingStates.map { _ in true },
            errorStates.map { _ in true },
            successStates.map { _ in false },
            idleStates.map { _ in false }
        ).and(requestExpandDetails.negate()).skipRepeats()

        statusDetailLabel.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ showStatusDetail.negate()

        let descriptionTopConstraint = statusDescriptionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        descriptionTopConstraint.isActive = true
        let descriptionCenterConstraint = statusDescriptionLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)

        func animateActiveChangeState(_ constraint: NSLayoutConstraint, _ newActiveState: Bool) { // captures self.view
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                (newActiveState ? NSLayoutConstraint.activate : NSLayoutConstraint.deactivate)([constraint])
                view.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
        }

        descriptionTopConstraint.reactive.makeBindingTarget(animateActiveChangeState) <~ showStatusDetail
        descriptionCenterConstraint.reactive.makeBindingTarget(animateActiveChangeState) <~ showStatusDetail.negate()
        lifetime.observeEnded {
            _ = descriptionTopConstraint
            _ = descriptionCenterConstraint
        }

        toggleRequestExpandedDetailsGestureRecognizer.reactive.makeBindingTarget { $0.isEnabled = $1 } <~ stateProducer.map(State.isIdle).skipRepeats().negate()

        requestExpandDetails <~ SignalProducer.merge(idleStates.map { _ in false },
                                                     errorStates.map { _ in true})
    }

    @IBAction func toggleRequestExpandDetails(_ sender: Any) {
        requestExpandDetails.value = !requestExpandDetails.value
    }
}

fileprivate enum State {
    case syncing(count: Int)
    case errors(count: Int, first: APIAccessError)
    case success(count: Int)
    case idle

    var count: Int {
        return State.getCount(from: self)
    }

    static func isSyncing(_ state: State) -> Bool {
        switch state {
        case .syncing(_): return true
        default: return false
        }
    }

    static func isErrors(_ state: State) -> Bool {
        switch state {
        case .errors(_): return true
        default: return false
        }
    }

    static func isSuccess(_ state: State) -> Bool {
        switch state {
        case .success(_): return true
        default: return false
        }
    }

    static func isIdle(_ state: State) -> Bool {
        switch state {
        case .idle: return true
        default: return false
        }
    }

    static func getCount(from state: State) -> Int {
        switch state {
        case .syncing(let count): return count
        case .errors(let count, _): return count
        case .success(let count): return count
        case .idle: return 0
        }
    }

    static func hasSingleItem(_ state: State) -> Bool {
        return state.count == 1
    }

    static func hasMultipleItems(_ state: State) -> Bool {
        return state.count > 1
    }

    static func firstError(in state: State) -> APIAccessError? {
        switch state {
        case .errors(_, let first): return first
        default: return nil
        }
    }
}

fileprivate func makeStateProducer(from statusesProducer: SignalProducer<[ActivityStatus], NoError>)
    -> SignalProducer<State, NoError> {
        let countsProducer = statusesProducer.map { statuses -> (Int, Int, Int, APIAccessError?) in
            let syncingCount = statuses.filter { $0.isExecuting }.count
            let successCount = statuses.filter { $0.isSuccessful }.count
            let errorCount = statuses.filter { $0.isError }.count
            let firstError = statuses.filter { $0.isError }.first?.error
            return (syncingCount, successCount, errorCount, firstError)
        }

        return countsProducer
            .map { (syncingCount, successCount, errorCount, firstError) in
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
        return APIAccessError.shortDescriptionForUser(from: self)
    }

    static func shortDescriptionForUser(from error: APIAccessError?) -> String {
        guard let error = error else {
            return "undefined"
        }
        switch error {
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

