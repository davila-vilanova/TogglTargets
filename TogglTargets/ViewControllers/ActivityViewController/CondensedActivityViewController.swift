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

class CondensedActivityViewController: NSViewController, BindingTargetProvider {

    private let requestExpandDetails = MutableProperty(false)

    // MARK: - Interface

    internal typealias Interface = (
        activityStatuses: SignalProducer<[ActivityStatus], NoError>,
        expandDetails: BindingTarget<Bool>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }


    @IBOutlet weak var statusDescriptionLabel: NSTextField!
    @IBOutlet weak var statusDetailLabel: NSTextField!
    @IBOutlet weak var horizontalLine: NSBox!
    @IBOutlet weak var toggleRequestExpandedDetailsGestureRecognizer: NSClickGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        let activityStatuses = lastBinding.latestOutput { $0.activityStatuses }
        requestExpandDetails.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.expandDetails } )

        horizontalLine.reactive.makeBindingTarget { $0.animator().isHidden = !$1 } <~ requestExpandDetails

        let stateProducer = makeStateProducer(from: activityStatuses)
        let syncingStates = stateProducer.filter(State.isSyncing)
        let errorStates = stateProducer.filter(State.isErrors)
        let singleErrorStates = errorStates.filter(State.hasSingleItem)
        let multipleErrorStates = errorStates.filter(State.hasMultipleItems)
        let successStates = stateProducer.filter(State.isSuccess)
        let idleStates = stateProducer.filter(State.isIdle)

        statusDescriptionLabel.reactive.text <~ SignalProducer.merge(
            syncingStates.map { _ in NSLocalizedString("status.condensed.all-data.syncing", comment: "data syncing in progress") },
            errorStates.map { _ in NSLocalizedString("status.condensed.all-data.error", comment: "there were errors while syncing data") },
            successStates.map { _ in NSLocalizedString("status.condensed.all-data.synced", comment: "all data up to date") }
        )

        statusDetailLabel.reactive.text <~ SignalProducer.merge(
            syncingStates.map(State.getCount).map {
                String.localizedStringWithFormat(NSLocalizedString("status.condensed.all-data.ops-in-progress",
                                                                   comment: "count of operations in progress"), $0)
            },
            singleErrorStates.map(State.firstError).map(APIAccessError.localizedDescription),
            multipleErrorStates.map(State.getCount).map {
                String.localizedStringWithFormat(NSLocalizedString("status.condensed.all-data.ops-with-errors",
                                                                   comment: "count of operations with errors"), $0)
            }
        )

        let shouldShowStatusDetail = SignalProducer.merge(
            syncingStates.map { _ in true },
            errorStates.map { _ in true },
            successStates.map { _ in false },
            idleStates.map { _ in false }
        ).and(requestExpandDetails.negate()).skipRepeats()

        statusDetailLabel.reactive.makeBindingTarget { $0.animator().isHidden = $1 } <~ shouldShowStatusDetail.negate()

        toggleRequestExpandedDetailsGestureRecognizer.reactive.makeBindingTarget { $0.isEnabled = $1 } <~ stateProducer.map(State.isIdle).skipRepeats().negate()

        let showStatusDetail: BindingTarget<Bool> = statusDetailLabel.reactive.makeBindingTarget { [unowned self] label, hidden in
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                label.isHidden = hidden
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: nil)
        }

        showStatusDetail <~ shouldShowStatusDetail.negate()

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
    var localizeDescription: String {
        return APIAccessError.localizedDescription(from: self)
    }

    static func localizedDescription(from error: APIAccessError?) -> String {
        guard let error = error else {
            return NSLocalizedString("status.condensed.error.unknown",
                                     comment: "condensed error message: unknown error")
        }
        switch error {
        case .noCredentials:
            return NSLocalizedString("status.condensed.error.no-credentials",
                                     comment: "condensed error message: no credentials configured")
        case .authenticationError(response: _):
            return NSLocalizedString("status.condensed.error.auth-failure",
                                     comment: "condensed error message: authentication failed")
        case .loadingSubsystemError(underlyingError: let underlyingError):
            return underlyingError.localizedDescription
        case .serverHiccups(response: let response, data: _):
            return String.localizedStringWithFormat(
                NSLocalizedString("status.condensed.error.server-hiccups",
                                  comment: "condensed error message: server returned an internal error"),
                response.statusCode)
        case .invalidJSON(underlyingError: _, data: _):
            return NSLocalizedString("status.condensed.error.unexpected-json",
                                     comment: "condensed error message: response body's JSON is unexpectedly formed")
        case .nonHTTPResponseReceived(response: _):
            return NSLocalizedString("status.condensed.error.non-http",
                                     comment: "condensed error message: received a non-http response")
        case .otherHTTPError(response: let response):
            return String.localizedStringWithFormat(NSLocalizedString("status.condensed.error.other-http",
                                                                      comment: "condensed error message: other HTTP error"), response.statusCode)
        }
    }
}
