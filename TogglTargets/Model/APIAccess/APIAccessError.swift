//
//  APIAccessError.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
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

/// The expected kinds of errors that can be triggered when attempting to communicate with Toggl's API.
// TODO: consider removing the word "error" from these cases
enum APIAccessError: Error {
    /// Triggered when no Toggl credentials are provided
    case noCredentials

    /// Triggered when the provided Toggl credentials are rejected by Toggl's API.
    /// The corresponding HTTP response is enclosed for the consumer's perusal.
    case authenticationError(response: HTTPURLResponse)

    /// Encloses an error triggered by the underlying `URLSession`. 
    case loadingSubsystemError(underlyingError: Error)

    /// Triggered when the connection produces a non-HTTP response. Spooky one. Don't expect it.
    /// The actual returned response is enclosed for the consumer.
    case nonHTTPResponseReceived(response: URLResponse)

    /// Triggered when the remote server (Toggl's backend) returns an error that belongs to the HTTP 500 family.
    /// The HTTP response and returned body data are enclosed.
    case serverHiccups(response: HTTPURLResponse, data: Data)

    /// Encloses an HTTP response with an unhandled error code.
    case otherHTTPError(response: HTTPURLResponse)

    /// Triggered when the JSON received in the response body could not be parsed (e.g. is malformed or the schema is
    /// unexpected).
    /// Encloses the parsing error and the data from the response body.
    case invalidJSON(underlyingError: Error, data: Data)
}

extension APIAccessError: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .noCredentials:
            return "No credentials configured"
        case .authenticationError(let response):
            return "Authentication error. Response is: \(response.debugDescription)"
        case .loadingSubsystemError(let underlyingError):
            return "Loading subsystem error: \(underlyingError)"
        case .nonHTTPResponseReceived(let response):
            return "Received non-HTTP response: \(response.debugDescription)"
        case .serverHiccups(let response, let data):
            return "Server error. Response is: \(response.debugDescription), data length is \(data.count)"
        case .otherHTTPError(let response):
            return "Other HTTP error. Response is: \(response.debugDescription)"
        case .invalidJSON(let underlyingError, let data):
            let body = String(data: data, encoding: .utf8) ?? "(body not available)"
            return "Invalid JSON. Underlying error: \(underlyingError), body is: \(body)"
        }
    }
}
