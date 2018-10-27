//
//  UniqueSubview.swift
//  TogglTargets
//
//  Created by David Dávila on 10.08.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

extension NSView {
    var uniqueSubview: BindingTarget<NSView> {
        return  reactive.makeBindingTarget { (parent: NSView, child: NSView) in
            if let previous = parent.subviews.first {
                previous.removeFromSuperview()
            }
            child.translatesAutoresizingMaskIntoConstraints = false
            parent.addSubview(child)

            // Pin edges to superview's edges
            child.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
        }
    }
}
