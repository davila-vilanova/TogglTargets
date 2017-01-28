//
//  ModelCache.swift
//  TogglGoals
//
//  Created by David Davila on 27.01.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Foundation

class ModelCache {
    private var userProfile: Profile?

    func retrieveUserProfile() -> (profile: Profile?, shouldRefresh: Bool) {
        return (userProfile, userProfile == nil)
    }

    func storeUserProfile(_ profile: Profile) {
        userProfile = profile
    }
}
