//
//  ContainmentSegue.swift
//
//  Created by David Davila on 26.05.17.
//  Copyright © 2017 David Dávila. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import Result

protocol ViewControllerContaining {
    func setContainedViewController(_ controller: NSViewController, containmentIdentifier: String?)
}

//fileprivate extension NSView {
//    func substituteSubviews(with newSubview: NSView) {
//        for subview in subviews {
//            subview.removeFromSuperview()
//        }
//        addSubview(newSubview)
//    }
//}

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

func setupContainment(of childController: NSViewController, in parentController: NSViewController, view: NSView, substituting previousChild: NSViewController? = nil) {

    let childView = childController.view
    let parentView = view

    if let previousChild = previousChild {
        let previousConstraints = parentView.constraints
        parentView.removeConstraints(previousConstraints)
        previousChild.view.removeFromSuperview()
        previousChild.removeFromParentViewController()
    }

    parentController.addChildViewController(childController)
    parentView.addSubview(childView)

    childView.translatesAutoresizingMaskIntoConstraints = false

    // Pin edges to superview's edges
    childView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
    childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
    childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
}

func setupContainment(of childViewControllers: SignalProducer<NSViewController, NoError>, in parentController: NSViewController, view: NSView) {
    let nonRepeating = childViewControllers.skipRepeats()
    let optionalized = nonRepeating.map { Optional($0) }
    let combined = optionalized.combinePrevious(nil)
    let currentDeoptionalized = combined.map { ($0.0, $0.1!) }

    parentController.reactive.makeBindingTarget { (parent, children) in
        setupContainment(of: children.1, in: parent, view: view, substituting: children.0)
    } <~ currentDeoptionalized
}

extension NSViewController { // TODO: 'where NSViewController is ViewControllerContaining'
    func initializeControllerContainment(containmentIdentifiers: [String]) {
        for identifier in containmentIdentifiers {
            performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: identifier), sender: self)
        }
    }
}
