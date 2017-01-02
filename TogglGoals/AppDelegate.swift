//
//  AppDelegate.swift
//  TogglGoals
//
//  Created by David Davila on 21/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, ModelCoordinatorContaining {
    lazy var modelCoordinator: ModelCoordinator? = {
        let togglAuth = TogglAuth(apiToken: "8e536ec872a3900a616198ecb3415c03") // TODO: to be retrieved
        let togglApiClient = TogglAPIClient(auth: togglAuth)
        let modelCache = ModelCache()
        return ModelCoordinator(apiClient: togglApiClient, cache: modelCache)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

