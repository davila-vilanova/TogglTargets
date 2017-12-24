//
//  TogglAPICredential.swift
//  Sandbox
//
//  Created by David Davila on 12/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

fileprivate let APITokenPassword = "api_token"
fileprivate let AuthHeaderKey = "Authorization"
fileprivate let BasicAuthHeaderPrefix = "Basic " // <-- end space built into the prefix
fileprivate let UsernamePasswordSeparator: Character = ":"

enum CredentialType: String {
    case email
    case apiToken
}

fileprivate func computeAuthHeaderValue(username: String, password: String) -> String {
    let data = "\(username)\(UsernamePasswordSeparator)\(password)".data(using: .utf8)!
    let credential = data.base64EncodedString(options: [])
    return "\(BasicAuthHeaderPrefix)\(credential)"
}

fileprivate func extractLoginDataFromAuthHeaderValue(_ authHeaderValue: String) -> (username: String, password: String)? {
    let prefixEndIndex = BasicAuthHeaderPrefix.endIndex
    let headerEndIndex = authHeaderValue.endIndex

    guard headerEndIndex > prefixEndIndex else {
        return nil
    }
    let deprefixed = authHeaderValue[prefixEndIndex..<headerEndIndex]

    if let encodedData = deprefixed.data(using: .utf8),
        let decodedData = Data(base64Encoded: encodedData),
        let decodedString = String(data: decodedData, encoding: .utf8),
        let separatorIndex = decodedString.index(of: UsernamePasswordSeparator) {
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

    var authHeaderKey = AuthHeaderKey
    private(set) var authHeaderValue: String
}

extension TogglAPIEmailCredential: Equatable {
    static func ==(lhs: TogglAPIEmailCredential, rhs: TogglAPIEmailCredential) -> Bool {
        return lhs.email == rhs.email
            && lhs.password == rhs.password
    }
}

struct TogglAPITokenCredential: TogglAPICredential {
    // Email is not stricty necessary but it allows to detect when an APIToken credential is
    // derived from an email and password-based credential and thus avoid treating
    // a credential transformation like a credential swap
    fileprivate let derivedFromEmail: String?
    private let apiToken: String
    var type: CredentialType { return CredentialType.apiToken }

    init?(apiToken: String, derivedFromEmail: String? = nil) {
        guard !apiToken.isEmpty else {
            return nil
        }
        self.apiToken = apiToken
        self.derivedFromEmail = derivedFromEmail
        self.authHeaderValue = computeAuthHeaderValue(username: apiToken, password: APITokenPassword)
    }

    var authHeaderKey: String = AuthHeaderKey
    private(set) var authHeaderValue: String

    func isLikelyDerived(from emailCredential: TogglAPIEmailCredential) -> Bool {
        guard let email = derivedFromEmail else {
            return false
        }
        return email == emailCredential.email
    }

    static func headersIncludeTokenAuthenticationEntry(_ headers: [AnyHashable : Any]) -> Bool {
        guard let headerValue = headers[AuthHeaderKey] as? String else {
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
}

extension TogglAPITokenCredential: Equatable {
    static func ==(lhs: TogglAPITokenCredential, rhs: TogglAPITokenCredential) -> Bool {
        return lhs.apiToken == rhs.apiToken
    }
}
