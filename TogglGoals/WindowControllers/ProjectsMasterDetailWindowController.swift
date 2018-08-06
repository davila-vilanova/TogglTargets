//
//  ProjectsMasterDetailWindowController.swift
//  TogglGoals
//
//  Created by David Davila on 11/12/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectsMasterDetailWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        let fx = NSVisualEffectView(frame: NSZeroRect)
        let v = NSView(frame: NSZeroRect)
        let root = window!.contentView!
        fx.translatesAutoresizingMaskIntoConstraints = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(fx)
        root.addSubview(v)

        v.leadingAnchor.constraint(equalTo: fx.leadingAnchor).isActive = true
        v.trailingAnchor.constraint(equalTo: fx.trailingAnchor).isActive = true
        v.topAnchor.constraint(equalTo: fx.topAnchor).isActive = true
        v.bottomAnchor.constraint(equalTo: fx.bottomAnchor).isActive = true

        fx.leadingAnchor.constraint(equalTo: root.leadingAnchor).isActive = true
        fx.widthAnchor.constraint(equalToConstant: 180).isActive = true
        fx.heightAnchor.constraint(equalToConstant: 22).isActive = true

        fx.blendingMode = .withinWindow
//        fx.material = .titlebar

        v.appearance = NSAppearance.init(named: NSAppearance.Name.vibrantLight)

        v.topAnchor.constraint(equalTo: root.topAnchor).isActive = true
    }

}
