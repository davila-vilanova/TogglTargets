//
//  UniqueSubview.swift
//  TogglTargets
//
//  Created by David Dávila on 10.08.18.
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
