//
//  APIAccessError.swift
//  Sandbox
//
//  Created by David Davila on 14/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

enum APIAccessError: Error {
    case authenticationError(response: HTTPURLResponse)
    case loadingSubsystemError(underlyingError: NSError)
    case invalidJSON(underlyingError: Any, data: Data)
    case unexpectedlyFormedJSON(json: Any)
}
