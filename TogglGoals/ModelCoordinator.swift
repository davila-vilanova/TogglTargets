//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ModelCoordinator {
    let apiClient: TogglAPIClient
    let cache: ModelCache

    init(apiClient: TogglAPIClient, cache: ModelCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func fetchUserProfile() -> AsynchronousResult<Profile> {
        let asyncResult = AsynchronousResult<Profile>()

        let cached = cache.retrieveUserProfile()
        let willRefresh = cached.shouldRefresh

        if let profile = cached.profile {
            asyncResult.setResult(data: profile, error: nil, isFurtherUpdateExpected: willRefresh)
        }

        if willRefresh {
            apiClient.fetchUserProfile(completion: { (profile, error) in
                if let profileToCache = profile {
                    self.cache.persistUserProfile(profileToCache)
                }
                asyncResult.setResult(data: profile, error: error, isFurtherUpdateExpected: false)
            })
        }

        return asyncResult
    }
}

class ModelCache {
    private var userProfile: Profile?

    func retrieveUserProfile() -> (profile: Profile?, shouldRefresh: Bool) {
        return (userProfile, userProfile != nil)
    }

    func persistUserProfile(_ profile: Profile) {
        userProfile = profile
    }
}
