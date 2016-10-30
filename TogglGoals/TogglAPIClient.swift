//
//  TogglAPIClient.swift
//  TogglGoals
//
//  Created by David Davila on 25/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

struct TogglAuth {
    let username: String?
    let password: String?
    let apiToken: String?

    init(username: String, password: String) {
        self.username = username
        self.password = password
        self.apiToken = nil
    }

    init(apiToken: String) {
        self.apiToken = apiToken
        self.username = nil
        self.password = nil
    }
}

class TogglAPIClient {
    let auth: TogglAuth

    init(auth: TogglAuth) {
        self.auth = auth
    }

    func fetchUserProfile(completion:(Profile?, Error?) -> ()) {
        
    }
}
