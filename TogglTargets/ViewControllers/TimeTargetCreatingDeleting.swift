//
//  TimeTargetCreatingDeleting.swift
//  TogglTargets
//
//  Created by David Dávila on 03.09.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

@objc protocol TimeTargetCreatingDeleting: NSUserInterfaceValidations {
    func createTimeTarget(_ sender: Any?)
    func deleteTimeTarget(_ sender: Any?)
}
