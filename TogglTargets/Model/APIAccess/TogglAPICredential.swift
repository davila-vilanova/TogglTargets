//
//  TogglAPICredential.swift
//  Sandbox
//
//  Created by David Davila on 12/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

private let APITokenPassword = "api_token"
private let authorizationHeaderKey = "Authorization"
private let basicAuthHeaderPrefix = "Basic " // <-- end space built into the prefix
private let usernamePasswordSeparator: Character = ":"

enum CredentialType: String {
    case email
    case apiToken
}

private func computeAuthHeaderValue(username: String, password: String) -> String {
    let data = "\(username)\(usernamePasswordSeparator)\(password)".data(using: .utf8)!
    let credential = data.base64EncodedString(options: [])
    return "\(basicAuthHeaderPrefix)\(credential)"
}

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

protocol TogglAPICredential {
    var type: CredentialType { get }

    var authHeaderKey: String { get }
    var authHeaderValue: String { get }
}

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
    static func ==(lhs: TogglAPIEmailCredential, rhs: TogglAPIEmailCredential) -> Bool {
        return lhs.email == rhs.email
            && lhs.password == rhs.password
    }
}

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
    static func ==(lhs: TogglAPITokenCredential, rhs: TogglAPITokenCredential) -> Bool {
        return lhs.apiToken == rhs.apiToken
    }
}
