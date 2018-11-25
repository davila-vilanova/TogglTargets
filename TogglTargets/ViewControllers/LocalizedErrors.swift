//
//  LocalizedErrors.swift
//  TogglTargets
//
//  Created by David Dávila on 23.06.18.
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

import Foundation

func localizedDescription(for error: APIAccessError) -> String {
    switch error {
    case .noCredentials:
        return NSLocalizedString("error.no-credentials", comment: "error description: no credentials configured")
    case .authenticationError(response: _):
        return NSLocalizedString("error.auth-failure", comment: "Authentication error. Check your Toggl credentials.")
    case .loadingSubsystemError(underlyingError: let underlyingError):
        return String.localizedStringWithFormat(
            NSLocalizedString("error.subsystem-error",
                              comment: "error description: request failed with underlying error"),
            underlyingError.localizedDescription)
    case .serverHiccups(response: let response, data: _):
        return String.localizedStringWithFormat(
            NSLocalizedString("error.server-hiccups",
                              comment: "error description: server returned an internal error"),
            response.statusCode)
    case .invalidJSON(underlyingError: _, data: _):
        return NSLocalizedString("error.unexpected-json",
                                 comment: "error description: response body's JSON is unexpectedly formed")
    case .nonHTTPResponseReceived(response: let response):
        return String.localizedStringWithFormat(
            NSLocalizedString("error.non-http",
                              comment: "error description: received a non-http response"),
            response.description)
    case .otherHTTPError(response: let response):
        return String.localizedStringWithFormat(
            NSLocalizedString("error.other-http",
                              comment: "error description: other HTTP error"),
            response.statusCode)
    }
}
