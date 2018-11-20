//
//  TimeTargetCreatingDeleting.swift
//  TogglTargets
//
//  Created by David Dávila on 03.09.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

/// A user interface element that validates and performs time target creation and deletion operations.
@objc protocol TimeTargetCreatingDeleting: NSUserInterfaceValidations {

    /// Creates a time target. The project ID for which to create a time target must be determined based on this
    /// element's internal state.
    func createTimeTarget(_ sender: Any?)

    /// Creates a time target. Which time target to delete must be determined based on this element's internal state.
    func deleteTimeTarget(_ sender: Any?)
}
