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

fileprivate extension NSView {
    func substituteSubviews(with newSubview: NSView) {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        addSubview(newSubview)
    }
}

class ContainmentSegue: NSStoryboardSegue { // TODO: it's too eager
    override func perform() {
        if let controller = sourceController as? NSViewController,
            let container = controller as? ViewControllerContaining,
            let contained = destinationController as? NSViewController {
            container.setContainedViewController(contained, containmentIdentifier: self.identifier.map { $0.rawValue })
        } else {
            print("Cannot perform containment segue between \(sourceController) and \(destinationController)")
        }
    }
}

func displayController(_ controller: NSViewController, in parentView: NSView) {
    let childView = controller.view
    guard parentView.subviews.first != childView else {
        return
    }
    parentView.substituteSubviews(with: childView)
    childView.translatesAutoresizingMaskIntoConstraints = false

    // Pin edges to superview's edges
    childView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
    childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
    childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
}

extension NSViewController { // TODO: 'where NSViewController is ViewControlelrContaining'
    func initializeControllerContainment(containmentIdentifiers: [String]) {
        for identifier in containmentIdentifiers {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
    }
}
