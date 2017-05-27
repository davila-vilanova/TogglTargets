//
//  ContainmentSegue.swift
//
//  Created by David Davila on 26.05.17.
//  Copyright © 2017 David Dávila. All rights reserved.
//

import Cocoa

protocol ViewControllerContaining {
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?)
}

extension NSView {
    func substituteSubviews(with newSubview: NSView) {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        addSubview(newSubview)
    }
}

class ContainmentSegue: NSStoryboardSegue {
    override func perform() {
        if let controller = sourceController as? NSViewController,
            let container = controller as? ViewControllerContaining,
            let contained = destinationController as? NSViewController {
            container.setContainedViewController(contained, containmentIdentifier: self.identifier)
        } else {
            print("Cannot perform containment segue between \(sourceController) and \(destinationController)")
        }
    }
}
