//
//  ModelCoordinator.swift
//  TogglGoals
//
//  Created by David Davila on 26/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

fileprivate func projectsDiffer(_ a: [Project]?, _ b: [Project]?) -> Bool {
    return true
}

// ModelCoordinator is not thread safe
internal class ModelCoordinator: NSObject {
    private let cache: ModelCache
    private let notificationCenter = NotificationCenter.default

    internal var profile: Profile? {
        didSet {
            let oldProjects: [Project]? = oldValue?.projects
            let newProjects = profile?.projects

            if projectsDiffer(newProjects, oldProjects) {
                let projectsToBroadcast: [Project]
                if let p = newProjects {
                    projectsToBroadcast = p
                } else {
                    projectsToBroadcast = [Project]()
                }

                let userInfo = [ModelCoordinator.ProjectsUpdatedNotificationProjectsKey: projectsToBroadcast]

                notificationCenter.post(name: ModelCoordinator.ProjectsUpdatedNotificationName, object: self, userInfo: userInfo)
            }
        }
    }
    internal var projects: [Project]? {
        get {
            return profile?.projects
        }
    }

    internal static let ProjectsUpdatedNotificationName = NSNotification.Name(rawValue: "ModelCoordinator.ProjectsUpdatedNotification")
    internal static let ProjectsUpdatedNotificationProjectsKey = "ModelCoordinator.ProjectsUpdatedNotification.ProjectsKey"

    private let apiCredential = TogglAPICredential()

    // TODO: inject these two?
    private lazy var mainQueue: DispatchQueue = {
        return DispatchQueue.main
    }()

    private lazy var networkQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "NetworkQueue"
        return q
    }()


    internal init(cache: ModelCache) {
        self.cache = cache
        super.init()
        retrieveUserProfile()
    }

    private func retrieveUserProfile() {
        let (profile, shouldRefresh) = self.cache.retrieveUserProfile()
        self.profile = profile
        if shouldRefresh {
            let op = ProfileLoadingOperation(credential: apiCredential)
            op.completionBlock = {
                if let profile = op.model {
                    self.cache.storeUserProfile(profile)
                    self.profile = profile
                }
            }
            networkQueue.addOperation(op)
        }
    }
}

protocol ModelCoordinatorContaining {
    var modelCoordinator: ModelCoordinator? { get set }
}
