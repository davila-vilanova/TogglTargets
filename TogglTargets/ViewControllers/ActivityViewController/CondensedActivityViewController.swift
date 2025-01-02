//
//  CondensedActivityViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 09.03.18.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import ReactiveSwift

class CondensedActivityViewController: NSViewController, BindingTargetProvider {

    // MARK: - Interface

    internal typealias Interface = (
        activityStatuses: SignalProducer<[ActivityStatus], Never>,
        expandDetails: BindingTarget<Bool>)

    private var lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    // MARK: - Private properties

    private let requestExpandDetails = MutableProperty(false)
    private lazy var stateProducer = makeStateProducer(from: activityStatuses)
    private lazy var syncingStates = stateProducer.filter(State.isSyncing)
    private lazy var errorStates = stateProducer.filter(State.isErrors)
    private lazy var singleErrorStates = errorStates.filter(State.hasSingleItem)
    private lazy var multipleErrorStates = errorStates.filter(State.hasMultipleItems)
    private lazy var successStates = stateProducer.filter(State.isSuccess)
    private lazy var idleStates = stateProducer.filter(State.isIdle)
    private lazy var activityStatuses = lastBinding.latestOutput { $0.activityStatuses }
    private lazy var shouldShowStatusDetail = SignalProducer.merge(
        syncingStates.map { _ in true },
        errorStates.map { _ in true },
        successStates.map { _ in false },
        idleStates.map { _ in false }
        ).and(requestExpandDetails.negate()).skipRepeats()

    // MARK: - Outlets and action

    @IBOutlet weak var statusDescriptionLabel: NSTextField!
    @IBOutlet weak var statusDetailLabel: NSTextField!
    @IBOutlet weak var horizontalLine: NSBox!
    @IBOutlet weak var toggleExpandedDetailsGestureRecognizer: NSClickGestureRecognizer!

    @IBAction func toggleRequestExpandDetails(_ sender: Any) {
        requestExpandDetails.value = !requestExpandDetails.value
    }

    // MARK: - Wiring

    override func viewDidLoad() {
        super.viewDidLoad()

        requestExpandDetails.bindOnlyToLatest(lastBinding.producer.skipNil().map { $0.expandDetails })

        horizontalLine.reactive.makeBindingTarget { $0.animator().isHidden = !$1 } <~ requestExpandDetails

        wireStatusDescriptionLabel()
        wireStatusDetailLabel()

        toggleExpandedDetailsGestureRecognizer.reactive
            .makeBindingTarget { $0.isEnabled = $1 } <~ stateProducer.map(State.isIdle).skipRepeats().negate()

        requestExpandDetails <~ SignalProducer.merge(idleStates.map { _ in false },
                                                     errorStates.map { _ in true})
    }

    private func wireStatusDescriptionLabel() {
        statusDescriptionLabel.reactive.text <~ SignalProducer.merge(
            syncingStates.map { _ in NSLocalizedString("status.condensed.all-data.syncing",
                                                       comment: "data syncing in progress") },
            errorStates.map { _ in NSLocalizedString("status.condensed.all-data.error",
                                                     comment: "there were errors while syncing data") },
            successStates.map { _ in NSLocalizedString("status.condensed.all-data.synced",
                                                       comment: "all data up to date") }
        )
    }

    private func wireStatusDetailLabel() {
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

        let showStatusDetail: BindingTarget<Bool> = statusDetailLabel.reactive
            .makeBindingTarget { [unowned self] label, hidden in
                NSAnimationContext.runAnimationGroup({ context in
                    context.allowsImplicitAnimation = true
                    label.isHidden = hidden
                    self.view.layoutSubtreeIfNeeded()
                }, completionHandler: nil)
        }

        showStatusDetail <~ shouldShowStatusDetail.negate()
    }
}

/// The state displayed by the condensed activity view, summarizing the underlying states that compose it.
private enum State {
    /// Some of the underlying states are syncing states.
    /// - count: The amount of syncing states.
    case syncing(count: Int)

    /// Some of the underlying states are errror states.
    /// - count: The amount of states with errors.
    /// - first: The error triggering the first of the error states.
    case errors(count: Int, first: APIAccessError)

    /// All the underlying states finished successfully.
    /// - count: The number of underlying states.
    case success(count: Int)

    /// There are no underlying states.
    case idle

    /// The count of states underlying the current state.
    /// The total number of underlying states might not match the returned count. For instance, if the state is .errors,
    /// only the underlying states with errors will be returned. Conversely the .success state implies that all
    /// underlying states are successful so the count will match the total amount of them.
    var count: Int {
        return State.getCount(from: self)
    }

    static func isSyncing(_ state: State) -> Bool {
        switch state {
        case .syncing: return true
        default: return false
        }
    }

    static func isErrors(_ state: State) -> Bool {
        switch state {
        case .errors: return true
        default: return false
        }
    }

    static func isSuccess(_ state: State) -> Bool {
        switch state {
        case .success: return true
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

/// Generates condensed states corresponding to the values received from a producer of collections of discrete states.
///
/// - parameters:
///   - statusesProducer: A producer of collections of individual states that will underlie the produced condensed
///                       states.
///
/// - returns: A prodeucer of condensed states.
private func makeStateProducer(from statusesProducer: SignalProducer<[ActivityStatus], Never>)
    -> SignalProducer<State, Never> {
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
    var localizedDescription: String {
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
            return String.localizedStringWithFormat(
                NSLocalizedString("status.condensed.error.other-http",
                                  comment: "condensed error message: other HTTP error"), response.statusCode)
        }
    }
}
