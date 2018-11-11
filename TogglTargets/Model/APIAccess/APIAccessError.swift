//
//  APIAccessError.swift
//  TogglTargets
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
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
