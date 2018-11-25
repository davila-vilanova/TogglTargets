//
//  TimeTargetCreatingDeleting.swift
//  TogglTargets
//
//  Created by David Dávila on 03.09.18.
//  Copyright 2016-2018 David Dávila
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
