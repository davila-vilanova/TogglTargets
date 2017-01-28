//
//  TogglAPICredential.swift
//  Sandbox
//
//  Created by David Davila on 12/01/2017.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

struct TogglAPICredential {
    let loginname = "david@davi.la"
    let password = "Go$zKDMKAcGmKByl7rwbE3MMMpKnAvKsz5rycpAI|usGsvBU1A"

    let authHeaderKey = "Authorization"

    var authHeaderValue: String {
        get {
            let data = "\(loginname):\(password)".data(using: .utf8)!
            let credential = data.base64EncodedString(options: [])
            return "Basic \(credential)"
        }
    }
}
