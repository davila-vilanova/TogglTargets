//
//  TogglAPICredential.swift
//  Sandbox
//
//  Created by David Davila on 12/01/2017.
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

/// The fixed password to use to authenticate against the Toggl API when using the API access token as the user name.
private let APITokenPassword = "api_token"

/// The key of the HTTP authorization header.
private let authorizationHeaderKey = "Authorization"

/// The beginning of the value of the HTTP authorization header, including a space at the end.
private let basicAuthHeaderPrefix = "Basic "

/// The token used as separator between the key and the value of the HTTP authorization key.
private let usernamePasswordSeparator: Character = ":"

/// Represents the kinds of authentication credential that the Toggl API accepts.
enum CredentialType: String {
    /// An authentication credential composed of email and password.
    case email

    /// An authentication credential formed by the account's API token.
    case apiToken
}

/// Generates the value for the HTTP authorization header.
///
/// - parameters:
///   - username: The token to use as user name.
///   - password: The token to use as password.
///
/// - returns: The string to use as the value of the HTTP `Authorization` header.
private func computeAuthHeaderValue(username: String, password: String) -> String {
    let data = "\(username)\(usernamePasswordSeparator)\(password)".data(using: .utf8)!
    let credential = data.base64EncodedString(options: [])
    return "\(basicAuthHeaderPrefix)\(credential)"
}

/// Extracts the user name and password from which an HTTP authorization header has been generated.
/// It is the reverse of `computeAuthHeaderValue(username: password:)`.
///
/// - parameters:
///   - authHeaderValue: the value of the HTTP `Authorization`.
///
/// - returns: A tuple composed of the username and password strings extracted from `authHeaderValue`.
private func extractLoginDataFromAuthHeaderValue(_ authHeaderValue: String) -> (username: String, password: String)? {
    let prefixEndIndex = basicAuthHeaderPrefix.endIndex
    let headerEndIndex = authHeaderValue.endIndex

    guard headerEndIndex > prefixEndIndex else {
        return nil
    }
    let deprefixed = authHeaderValue[prefixEndIndex..<headerEndIndex]

    if let encodedData = deprefixed.data(using: .utf8),
        let decodedData = Data(base64Encoded: encodedData),
        let decodedString = String(data: decodedData, encoding: .utf8),
        let separatorIndex = decodedString.index(of: usernamePasswordSeparator) {
        let username = decodedString[decodedString.startIndex..<separatorIndex]
        let password = decodedString[decodedString.index(after: separatorIndex)..<decodedString.endIndex]
        return (String(username), String(password))
    } else {
        return nil
    }
}

/// A credential that can be used to authenticate against the Toggl API.
protocol TogglAPICredential {
    var type: CredentialType { get }

    var authHeaderKey: String { get }
    var authHeaderValue: String { get }
}

/// A `TogglAPICredential` composed of the user's email and password.
struct TogglAPIEmailCredential: TogglAPICredential {
    fileprivate let email: String
    private let password: String
    var type: CredentialType { return CredentialType.email }

    init?(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            return nil
        }
        self.email = email
        self.password = password
        self.authHeaderValue = computeAuthHeaderValue(username: email, password: password)
    }

    var authHeaderKey = authorizationHeaderKey
    private(set) var authHeaderValue: String
}

extension TogglAPIEmailCredential: Equatable {
    static func == (lhs: TogglAPIEmailCredential, rhs: TogglAPIEmailCredential) -> Bool {
        return lhs.email == rhs.email
            && lhs.password == rhs.password
    }
}

/// A `TogglAPICredential` composed of API token assigned to the user's Toggl account.
struct TogglAPITokenCredential: TogglAPICredential {
    let apiToken: String
    var type: CredentialType { return CredentialType.apiToken }

    init?(apiToken: String) {
        guard !apiToken.isEmpty else {
            return nil
        }
        self.apiToken = apiToken
        self.authHeaderValue = computeAuthHeaderValue(username: apiToken, password: APITokenPassword)
    }

    var authHeaderKey: String = authorizationHeaderKey
    private(set) var authHeaderValue: String

    static func headersIncludeTokenAuthenticationEntry(_ headers: [AnyHashable: Any]) -> Bool {
        guard let headerValue = headers[authorizationHeaderKey] as? String else {
            return false
        }
        return extractLoginDataFromAuthHeaderValue(headerValue)?.password == APITokenPassword
    }
}

extension TogglAPITokenCredential: StorableInUserDefaults {
    private enum UserDefaultsKey: String {
        case apiToken
    }

    init?(userDefaults: UserDefaults) {
        guard let token = userDefaults.string(forKey: UserDefaultsKey.apiToken.rawValue) else {
            return nil
        }
        self.init(apiToken: token)
    }

    func write(to userDefaults: UserDefaults) {
        userDefaults.set(apiToken, forKey: UserDefaultsKey.apiToken.rawValue)
    }

    static func delete(from userDefaults: UserDefaults) {
        userDefaults.removeObject(forKey: UserDefaultsKey.apiToken.rawValue)
    }
}

extension TogglAPITokenCredential: Equatable {
    static func == (lhs: TogglAPITokenCredential, rhs: TogglAPITokenCredential) -> Bool {
        return lhs.apiToken == rhs.apiToken
    }
}
