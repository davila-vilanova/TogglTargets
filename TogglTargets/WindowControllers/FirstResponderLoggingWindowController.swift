//
//  FirstResponderLoggingWindowController.swift
//  TogglTargets
//
//  Created by David Davila on 11/12/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa
import ReactiveSwift

class FirstResponderLoggingWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        reactive.lifetime += window!.reactive.producer(forKeyPath: "firstResponder").startWithValues({
            print ("first responder: \(($0 != nil) ? String(describing: $0!) : "null")")
        })
    }

}
