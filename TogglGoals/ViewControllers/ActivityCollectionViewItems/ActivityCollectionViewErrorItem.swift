//
//  ActivityCollectionViewErrorItem.swift
//  TogglGoals
//
//  Created by David Dávila on 02.01.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import ReactiveCocoa

class ActivityCollectionViewErrorItem: NSCollectionViewItem, ActivityDisplaying {

    @IBOutlet weak var failureDescriptionTextField: NSTextField!
    @IBOutlet weak var errorDescriptionTextField: NSTextField!
    @IBOutlet weak var recoverySuggestionTextField: NSTextField!
    @IBOutlet weak var recoveryButton: NSButton!


    func setDisplayActivity(_ activity: ActivityStatus.Activity) {
        let retrieveWhat: String

        switch activity {
        case .retrieveProfile: retrieveWhat = "profile"
        case .retrieveProjects: retrieveWhat = "projects"
        case .retrieveReports: retrieveWhat = "reports"
        case .retrieveRunningEntry: retrieveWhat = "running entry"
        case .retrieveAll: retrieveWhat = "data from Toggl"
        }

        failureDescriptionTextField.stringValue = "Failed to retrieve \(retrieveWhat)"
    }

    func setError(_ error: APIAccessError) {
        let errorDescription: String
        let recoverySuggestion: String?
        switch error {
            case .noCredentials:
            errorDescription = "No credentials set"
            recoverySuggestion = "Click here to set your Toggl credentials"
        case .authenticationError:
            errorDescription = "Invalid credentials"
            recoverySuggestion = "Click here to set your Toggl credentials"
        case .loadingSubsystemError(let underlyingError):
            errorDescription = "Loading failed (\(String(describing: underlyingError))"
            recoverySuggestion = nil
        case .nonHTTPResponseReceived(let response):
            errorDescription = "Non HTTP response (\(String(describing: response))"
            recoverySuggestion = nil
        case .serverHiccups(let response, _):
            errorDescription = "Server hiccuped with status code: \(response.statusCode)"
            recoverySuggestion = nil
        case .otherHTTPError(let response):
            errorDescription = "Unexpected HTTP error with status code: \(response.statusCode)"
            recoverySuggestion = nil
        case .invalidJSON:
            errorDescription = "Unexpectedly formed response JSON"
            recoverySuggestion = nil
        }

        errorDescriptionTextField.stringValue = errorDescription
        if let suggestion = recoverySuggestion {
            recoverySuggestionTextField.stringValue = suggestion
            recoverySuggestionTextField.isHidden = false
        } else {
            recoverySuggestionTextField.isHidden = true
        }
    }

    func setRetryAction(_ action: RetryAction) {
        recoveryButton.reactive.pressed = CocoaAction(action)
    }
}
