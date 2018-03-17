//
//  ViewController.swift
//  ToggleCollectionView
//
//  Created by David Dávila on 16.03.18.
//  Copyright © 2018 davi.la. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class ViewController: NSViewController {

    private let wantsExpandedDetails = MutableProperty(true)
    @IBOutlet weak var detailsView: NSView!

    @IBOutlet weak var rootHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var summaryTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var summaryHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var summaryBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailsHeightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        detailsView.reactive.makeBindingTarget(on: UIScheduler(), animateOpacity) <~ wantsExpandedDetails.map { $0 ? (0.0, 1.0) : (1.0, 0.0) }

        let summaryTop = summaryTopConstraint.constant
        let summaryHeight = summaryHeightConstraint.constant
        let summaryBottom = summaryBottomConstraint.constant
        let detailsHeight = detailsHeightConstraint.constant
        let collapsedHeight = summaryTop + summaryHeight + summaryBottom
        let expandedHeight = collapsedHeight + detailsHeight + summaryTop
        rootHeightConstraint.reactive
            .makeBindingTarget(on: UIScheduler()) { $0.animator().constant = $1 }
            <~ wantsExpandedDetails.map { $0 ? expandedHeight : collapsedHeight }
    }

    @IBAction func toggleDetails(_ sender: NSButton) {
        wantsExpandedDetails.value = sender.state == .on
    }

    @IBAction func stop(_ sender: NSButton) {
        _ = false
    }
}

fileprivate func animateOpacity(view: NSView, values: (from: Double, to: Double)) {
    guard let layer = view.layer else {
        return
    }
    let (from, to) = values
    let opacityKey = "opacity"
    let animation = CABasicAnimation(keyPath: opacityKey)
    animation.fromValue = from
    animation.toValue = to
    layer.add(animation, forKey: opacityKey)
}
