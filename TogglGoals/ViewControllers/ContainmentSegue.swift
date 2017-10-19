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
            subview.animator().removeFromSuperview()
        }
        animator().addSubview(newSubview)
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
    guard parentView.subviews.first != controller.view else {
        return
    }
    parentView.substituteSubviews(with: controller.view)
    controller.view.autoPinEdgesToSuperviewEdges()
}

extension NSViewController { // TODO: 'where NSViewController is ViewControlelrContaining'
    func initializeControllerContainment(containmentIdentifiers: [String]) {
        for identifier in containmentIdentifiers {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
    }
}
