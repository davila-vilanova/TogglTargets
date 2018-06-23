//
//  APIAccessError.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

// TODO: consider removing the word "error" from these cases
enum APIAccessError: Error {
    case noCredentials
    case authenticationError(response: HTTPURLResponse)
    case loadingSubsystemError(underlyingError: Error)
    case nonHTTPResponseReceived(response: URLResponse)
    case serverHiccups(response: HTTPURLResponse, data: Data)
    case otherHTTPError(response: HTTPURLResponse)
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

