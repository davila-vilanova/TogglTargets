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

    /// Sets this view's unique subview.
    /// Adjusts the layout of the subview to match this view's size.
    /// If this view already contains a subview, removes it first.
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
