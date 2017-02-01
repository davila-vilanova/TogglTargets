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
        let modelCache = ModelCache()
        let goalsStore = GoalsStore()
        return ModelCoordinator(cache: modelCache, goalsStore: goalsStore)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

