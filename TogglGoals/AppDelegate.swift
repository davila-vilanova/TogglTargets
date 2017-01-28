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
        return ModelCoordinator(cache: modelCache)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

