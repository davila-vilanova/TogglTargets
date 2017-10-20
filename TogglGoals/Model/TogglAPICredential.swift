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

enum CredentialType: String {
    case username
    case apiToken

    private static let key = "CredentialType"

    fileprivate static func read(from userDefaults: UserDefaults) -> CredentialType? {
        guard let typeString = userDefaults.string(forKey: CredentialType.key),
            let type = CredentialType(rawValue: typeString) else {
                return nil
        }
        return type
    }

    fileprivate func save(to userDefaults: UserDefaults) {
        userDefaults.set(rawValue, forKey: CredentialType.key)
    }
}

fileprivate enum CredentialValueKey: String {
    case username
    case password
    case apiToken
}

fileprivate func computeAuthHeaderValue(username: String, password: String) -> String {
    let data = "\(username):\(password)".data(using: .utf8)!
    let credential = data.base64EncodedString(options: [])
    return "Basic \(credential)"
}

protocol TogglAPICredential {
    var type: CredentialType { get }

    var authHeaderKey: String { get }
    var authHeaderValue: String { get }

    func write(to userDefaults: UserDefaults)
}

func readTogglAPICredential(from userDefaults: UserDefaults) -> TogglAPICredential? {
    switch CredentialType.read(from: userDefaults) {
    case .username?: return TogglAPIUsernameCredential(userDefaults: userDefaults)
    case .apiToken?: return TogglAPITokenCredential(userDefaults: userDefaults)
    default: return nil
    }
}

struct TogglAPIUsernameCredential: TogglAPICredential {
    private let username: String
    private let password: String
    var type: CredentialType { return CredentialType.username }

    init(username: String, password: String) {
        self.username = username
        self.password = password
        self.authHeaderValue = computeAuthHeaderValue(username: username, password: password)
    }

    init?(userDefaults: UserDefaults) {
        guard let username = userDefaults.string(forKey: CredentialValueKey.username.rawValue),
            let password = userDefaults.string(forKey: CredentialValueKey.password.rawValue) else {
                return nil
        }
        self.init(username: username, password: password)
    }

    var authHeaderKey = AuthHeaderKey
    private(set) var authHeaderValue: String

    func write(to userDefaults: UserDefaults) {
        type.save(to: userDefaults)
        userDefaults.set(username, forKey: CredentialValueKey.username.rawValue)
        userDefaults.set(password, forKey: CredentialValueKey.password.rawValue)
    }
}

struct TogglAPITokenCredential: TogglAPICredential {
    private let apiToken: String
    var type: CredentialType { return CredentialType.apiToken }

    init(apiToken: String) {
        self.apiToken = apiToken
        self.authHeaderValue = computeAuthHeaderValue(username: apiToken, password: APITokenPassword)
    }

    init?(userDefaults: UserDefaults) {
        guard let token = userDefaults.string(forKey: CredentialValueKey.apiToken.rawValue) else {
            return nil
        }
        self.init(apiToken: token)
    }

    var authHeaderKey: String = AuthHeaderKey
    private(set) var authHeaderValue: String

    func write(to userDefaults: UserDefaults) {
        type.save(to: userDefaults)
        userDefaults.set(apiToken, forKey: CredentialValueKey.apiToken.rawValue)
    }
}
