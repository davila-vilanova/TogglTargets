//
//  DetailedActivityViewController.swift
//  TogglGoals
//
//  Created by David Davila on 26.03.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift

fileprivate let itemHeight: CGFloat = 24
fileprivate let kHeightConstraintIdentifier = "HeightConstraintIdentifier"
fileprivate let kAnimationDuration = 0.10

class DetailedActivityViewController: NSViewController {

    func connectInterface(activityStatuses: SignalProducer<[ActivityStatus], NoError>) {
        self.activityStatuses <~ activityStatuses
    }

    private let activityStatuses = MutableProperty([ActivityStatus]())

    private weak var profileContainer: NSView!
    private weak var projectsContainer: NSView!
    private weak var reportsContainer: NSView!
    private weak var runningEntryContainer: NSView!

    private var profileActivityController: NSViewController?
    private var projectsActivityController: NSViewController?
    private var reportsActivityController: NSViewController?
    private var runningEntryActivityController: NSViewController?

    private func activityViewContainer(for activity: ActivityStatus.Activity) -> NSView {
        switch activity {
        case .syncProfile: return profileContainer
        case .syncProjects: return projectsContainer
        case .syncReports: return reportsContainer
        case .syncRunningEntry: return runningEntryContainer
        }
    }

    private func activityController(for activity: ActivityStatus.Activity) -> NSViewController? {
        switch activity {
        case .syncProfile: return profileActivityController
        case .syncProjects: return projectsActivityController
        case .syncReports: return reportsActivityController
        case .syncRunningEntry: return runningEntryActivityController
        }
    }

    private func setActivityController(_ controller: NSViewController?, for activity: ActivityStatus.Activity) {
        switch activity {
        case .syncProfile: profileActivityController = controller
        case .syncProjects: projectsActivityController = controller
        case .syncReports: reportsActivityController = controller
        case .syncRunningEntry: runningEntryActivityController = controller
        }
    }

    private func clearActivityController(for activity: ActivityStatus.Activity) {
        setActivityController(nil, for: activity)
    }

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

        func attachContainerView(_ containerView: NSView, under previousView: NSView? = nil) {
            view.addSubview(containerView)
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            containerView.topAnchor.constraint(equalTo: (previousView?.bottomAnchor ?? view.topAnchor)).isActive = true

            let heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
            heightConstraint.identifier = kHeightConstraintIdentifier
            heightConstraint.isActive = true
        }

        attachContainerView(profileContainer)
        attachContainerView(projectsContainer, under: profileContainer)
        attachContainerView(reportsContainer, under: projectsContainer)
        attachContainerView(runningEntryContainer, under: reportsContainer)

        updateActivities <~ activityStatuses.combinePrevious([ActivityStatus]())
    }

    private func updateActivitiesState(from previousStatus: [ActivityStatus], to newStatus: [ActivityStatus]) {
        let previousStatusByActivity = Dictionary(uniqueKeysWithValues: previousStatus.map { ($0.activity, $0) } )
        let newStatusByActivity = Dictionary(uniqueKeysWithValues: newStatus.map { ($0.activity, $0) } )

        let previousActivities = Set(previousStatusByActivity.keys)
        let newActivities = Set(newStatusByActivity.keys)

        let activitiesToAdd = newActivities.subtracting(previousActivities)
        let activitiesToRemove = previousActivities.subtracting(newActivities)
        let activitiesToSwap = (newActivities.intersection(previousActivities)).filter { !previousStatusByActivity[$0]!.representedBySameController(as: newStatusByActivity[$0]!) }

        for activity in activitiesToRemove {
            let controller = activityController(for: activity)!
            detachActivityView(controller.view)
            clearActivityController(for: activity)
        }

        for activity in activitiesToAdd {
            let activityStatus = newStatusByActivity[activity]!
            let controller = makeActivityController(for: activityStatus)
            setActivityController(controller, for: activity)
            let containerView = activityViewContainer(for: activity)
            attachActivityView(controller.view, to: containerView)
        }

        for activity in activitiesToSwap {
            let previousController = activityController(for: activity)!
            let newActivityStatus = newStatusByActivity[activity]!
            let newController = makeActivityController(for: newActivityStatus)
            swapActivityView(previousController.view, newView: newController.view)
            setActivityController(newController, for: activity)
        }

        for activityStatus in newStatus {
            let controller = activityController(for: activityStatus.activity)!
            controller.representedObject = activityStatus
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

fileprivate func swapActivityView(_ previousView: NSView, newView: NSView) {
    guard let superview = previousView.superview else {
        return
    }

    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = kAnimationDuration
    superview.animator().addSubview(newView)
    previousView.animator().removeFromSuperview()
    NSAnimationContext.endGrouping()

    newView.translatesAutoresizingMaskIntoConstraints = false
    newView.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
    newView.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
    newView.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
    newView.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
}

fileprivate func makeActivityController(for status: ActivityStatus) -> NSViewController {
    switch status {
    case .executing(_): return SyncingActivityViewController()
    case .succeeded(_): return ActivitySuccessViewController()
    case .error(_, _, _): return ActivityErrorViewController()
    }
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

fileprivate extension ActivityStatus {
    func representedBySameController(as anotherStatus: ActivityStatus) -> Bool {
        return isExecuting != anotherStatus.isExecuting &&
            isSuccessful != anotherStatus.isSuccessful &&
            isError != anotherStatus.isError
    }
}
