//
//  LocalizedErrors.swift
//  TogglTargets
//
//  Created by David Dávila on 23.06.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Foundation

func localizedDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials:
        return NSLocalizedString("error.no-credentials", comment: "error description: no credentials configured")
    case .authenticationError(response: _):
        return NSLocalizedString("error.auth-failure", comment: "Authentication error. Check your Toggl credentials.")
    case .loadingSubsystemError(underlyingError: let underlyingError):
        return String.localizedStringWithFormat(NSLocalizedString("error.subsystem-error",
                                                                  comment: "error description: request failed with underlying error"),
                                                underlyingError.localizedDescription)
    case .serverHiccups(response: let response, data: _):
        return String.localizedStringWithFormat(NSLocalizedString("error.server-hiccups",
                                                                  comment: "error description: server returned an internal error"),
                                                response.statusCode)
    case .invalidJSON(underlyingError: _, data: _):
        return NSLocalizedString("error.unexpected-json",
                                 comment: "error description: response body's JSON is unexpectedly formed")
    case .nonHTTPResponseReceived(response: let response):
        return String.localizedStringWithFormat(NSLocalizedString("error.non-http",
                                                                  comment: "error description: received a non-http response"),
                                                response.description)
    case .otherHTTPError(response: let response):
        return String.localizedStringWithFormat(NSLocalizedString("error.other-http",
                                                                  comment: "error description: other HTTP error"),
                                                response.statusCode)
    }
}
