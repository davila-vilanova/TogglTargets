//
//  LocalizedErrors.swift
//  TogglGoals
//
//  Created by David Dávila on 23.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

func localizedDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials:
        return "No credentials configured. Please configure your Toggl credentials."
    case .authenticationError(response: _):
        return "Authentication error. Check your Toggl credentials."
    case .loadingSubsystemError(underlyingError: let underlyingError):
        return "The request failed with the following error:\n\(underlyingError.localizedDescription)"
    case .serverHiccups(response: let response, data: _):
        return "It seems like the Toggl server is experiencing internal difficulties. Response code is \(response.statusCode)."
    case .invalidJSON(underlyingError: _, data: _):
        return "Got some unexpectedly formed JSON as part of the response."
    case .nonHTTPResponseReceived(response: let response):
        return "Received what seems not to be an HTTP response: \(response.description)"
    case .otherHTTPError(response: let response):
        return "Received an HTTP error that I don't know how to handle. Response code is \(response.statusCode)."
    }
}
