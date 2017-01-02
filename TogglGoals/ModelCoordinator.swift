//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

// ModelCoordinator is not thread safe
class ModelCoordinator: NSObject {
    let apiClient: TogglAPIClient
    let cache: ModelCache

    var pendingBackendProfileRetrievalCompletionHandlers = [BackendProfileRetrievalCompletionHandler]()
    var profileRetrievalOperationRunning = false

    private lazy var mainQueue: DispatchQueue = {
        return DispatchQueue.main
    }()

    init(apiClient: TogglAPIClient, cache: ModelCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func retrieveUserProfile(_ updateResultHandler: ((AsynchronousResult<Profile>) -> Void)?) {
        let asyncResult = AsynchronousResult<Profile>()
        asyncResult.availabilityCallback = updateResultHandler

        let cached = cache.retrieveUserProfile()

        asyncResult.data = cached.profile
        asyncResult.isFinal = !cached.shouldRefresh

        if cached.shouldRefresh {
            retrieveUserProfileFromBackend() { (profile, error) in
                asyncResult.data = profile
                asyncResult.error = error
                asyncResult.isFinal = true
            }
        }
    }

    func retrieveUserProjects(_ updateProjectsResultHandler: ((AsynchronousResult<[Project]>) -> Void)?) -> AsynchronousResult<[Project]> {
        let projectsResult = AsynchronousResult<[Project]>()
        projectsResult.availabilityCallback = updateProjectsResultHandler

        func updatedProfileResultAvailable(_ updatedProfileResult: AsynchronousResult<Profile>) {
            projectsResult.setResult(data: updatedProfileResult.data?.projects,
                                     error: updatedProfileResult.finalError,
                                     final: updatedProfileResult.isFinal)
        }

        let profileResult = retrieveUserProfile { (updatedProfileResult) in
            updatedProfileResultAvailable(updatedProfileResult)
        }

        if let projects = profileResult.data?.projects {
            projectsResult.setResult(data: projects, error: nil, final: profileResult.isFinal)
        }

        return projectsResult
    }

    // MARK: Mediated toggl backend access

    private func retrieveUserProfileFromBackend(_ completion: @escaping BackendProfileRetrievalCompletionHandler) {
        pendingBackendProfileRetrievalCompletionHandlers.append(completion)

        if !profileRetrievalOperationRunning {
            profileRetrievalOperationRunning = true
            apiClient.retrieveUserProfile(queue: mainQueue) { (profile, error) in
                if let profileToCache = profile {
                    self.cache.storeUserProfile(profileToCache)
                }
                for completionHandler in self.pendingBackendProfileRetrievalCompletionHandlers {
                    completionHandler(profile, error)
                }
                self.pendingBackendProfileRetrievalCompletionHandlers.removeAll()
                self.profileRetrievalOperationRunning = false
            }
        }
    }
}

class ModelCache {
    private var userProfile: Profile?

    func retrieveUserProfile() -> (profile: Profile?, shouldRefresh: Bool) {
        return (userProfile, userProfile == nil)
    }

    func storeUserProfile(_ profile: Profile) {
        userProfile = profile
    }
}

protocol ModelCoordinatorContaining {
    var modelCoordinator: ModelCoordinator? { get set }
}
