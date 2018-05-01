//
//  KeyViewsProviding.swift
//  TogglGoals
//
//  Created by David Dávila on 01.05.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

internal protocol KeyViewsProviding {
    var firstKeyView: NSView { get }
    var lastKeyView: NSView { get }
}
