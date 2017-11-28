//
//  APIAccessError.swift
//  TogglGoals
//
//  Created by David Dávila on 28.11.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

enum APIAccessError: Error {
    case loadingSubsystemError(underlyingError: Error)
    case nonHTTPResponseReceived(response: URLResponse)
    case authenticationError(response: HTTPURLResponse)
    case serverHiccups(response: HTTPURLResponse, data: Data)
    case otherHTTPError(response: HTTPURLResponse)
    case invalidJSON(underlyingError: Error, data: Data)
}
