//
//  ViewController.swift
//  LayoutTests
//
//  Created by David Davila on 24.03.18.
//  Copyright © 2018 David Dávila. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
@testable import TogglGoals_MacOS

fileprivate let itemHeight: CGFloat = 30
fileprivate let kHeightConstraintIdentifier = "HeightConstraintIdentifier"
fileprivate let kAnimationDuration = 0.10

class LayoutTestsViewController: NSViewController {
    func connectInterface(activityStatuses: SignalProducer<[ActivityStatus], NoError>) {
        self.activityStatuses <~ activityStatuses
    }

    private let activityStatuses = MutableProperty([ActivityStatus]())

    private weak var profileContainer: NSView!
    private weak var projectsContainer: NSView!
    private weak var reportsContainer: NSView!
    private weak var runningEntryContainer: NSView!

    private func activityViewContainer(for activity: ActivityStatus.Activity) -> NSView {
        switch activity {
        case .syncProfile: return profileContainer
        case .syncProjects: return projectsContainer
        case .syncReports: return reportsContainer
        case .syncRunningEntry: return runningEntryContainer
        }
    }

    private let activityViewControllers: [ActivityStatus.Activity : ActivityCollectionViewItem] = [
        .syncProfile : ActivityCollectionViewItem(),
        .syncProjects : ActivityCollectionViewItem(),
        .syncReports: ActivityCollectionViewItem(),
        .syncRunningEntry : ActivityCollectionViewItem()
    ]

    private let (lifetime, token) = Lifetime.make()
    private lazy var updateActivities =
        BindingTarget<([ActivityStatus], [ActivityStatus])>(on: UIScheduler(), lifetime: lifetime) { [weak self] in
            self?.updateActivitiesState(from: $0, to: $1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let profileContainer = makeContainerView(identifier: "ProfileContainerView")
        let projectsContainer = makeContainerView(identifier: "ProjectsContainerView")
        let reportsContainer = makeContainerView(identifier: "ReportsContainerView")
        let runningEntryContainer = makeContainerView(identifier: "RunningEntryContainer")

        self.profileContainer = profileContainer
        self.projectsContainer = projectsContainer
        self.reportsContainer = reportsContainer
        self.runningEntryContainer = runningEntryContainer

        attachContainerView(profileContainer)
        attachContainerView(projectsContainer, under: profileContainer)
        attachContainerView(reportsContainer, under: projectsContainer)
        attachContainerView(runningEntryContainer, under: reportsContainer)

        updateActivities <~ activityStatuses.combinePrevious([ActivityStatus]())
    }

    private func attachContainerView(_ containerView: NSView, under previousView: NSView? = nil) {
        view.addSubview(containerView)
        containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        containerView.topAnchor.constraint(equalTo: (previousView?.bottomAnchor ?? view.topAnchor)).isActive = true

        let heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.identifier = kHeightConstraintIdentifier
        heightConstraint.isActive = true
    }

    private func updateActivitiesState(from previous: [ActivityStatus], to current: [ActivityStatus]) {
        let previousActivities = Set(previous.map { $0.activity })
        let currentActivities = Set(current.map { $0.activity })

        let add = currentActivities.subtracting(previousActivities)
        let remove = previousActivities.subtracting(currentActivities)

        for activity in add {
            let viewController = activityViewControllers[activity]!
            let containerView = activityViewContainer(for: activity)
            attachActivityView(viewController.view, to: containerView)
        }
        for activity in remove {
            let viewController = activityViewControllers[activity]!
            detachActivityView(viewController.view)
        }

        for activityStatus in current {
            let viewController = activityViewControllers[activityStatus.activity]!
            viewController.representedObject = activityStatus
        }
    }
}


fileprivate func makeContainerView(identifier: String) -> NSView {
    let view = NSView()
    view.identifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

fileprivate func attachActivityView(_ activityView: NSView, to containerView: NSView) {
    activityView.translatesAutoresizingMaskIntoConstraints = false
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = kAnimationDuration
    containerView.constraintWithIdentifier(kHeightConstraintIdentifier)!.animator().constant = itemHeight
    containerView.addSubview(activityView)
    NSAnimationContext.endGrouping()

    activityView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
    activityView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    activityView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
    activityView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
}

fileprivate func detachActivityView(_ activityView: NSView) {
    guard let superview = activityView.superview else {
        return
    }
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = kAnimationDuration
    NSAnimationContext.current.completionHandler = {
        activityView.removeFromSuperview()
    }
    superview.constraintWithIdentifier(kHeightConstraintIdentifier)!.animator().constant = 0
    NSAnimationContext.endGrouping()
}

fileprivate extension NSView {
    func constraintWithIdentifier(_ identifier: String) -> NSLayoutConstraint? {
        for constraint in constraints {
            if constraint.identifier == identifier {
                return constraint
            }
        }
        return nil
    }
}
