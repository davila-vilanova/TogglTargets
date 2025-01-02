//
//  DetailedActivityViewController.swift
//  TogglTargets
//
//  Created by David Davila on 26.03.18.
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

class DetailedActivityViewController: NSViewController, BindingTargetProvider {

    internal typealias Interface = SignalProducer<[ActivityStatus], Never>

    private let lastBinding = MutableProperty<Interface?>(nil)
    internal var bindingTarget: BindingTarget<Interface?> { return lastBinding.bindingTarget }

    private weak var profileActivityContainer: NSView!
    private weak var projectsActivityContainer: NSView!
    private weak var reportsActivityContainer: NSView!
    private weak var runningEntryActivityContainer: NSView!

    private var profileActivityController: NSViewController?
    private var projectsActivityController: NSViewController?
    private var reportsActivityController: NSViewController?
    private var runningEntryActivityController: NSViewController?

    private func activityViewContainer(for activity: ActivityStatus.Activity) -> NSView {
        switch activity {
        case .syncProfile: return profileActivityContainer
        case .syncProjects: return projectsActivityContainer
        case .syncReports: return reportsActivityContainer
        case .syncRunningEntry: return runningEntryActivityContainer
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

    private lazy var updateActivities =
        BindingTarget(on: UIScheduler(), lifetime: reactive.lifetime) { [weak self] in
            self?.updateActivitiesState(from: $0, to: $1)
    }

    @IBOutlet weak var rootStackView: NSStackView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let profileContainer = makeContainerView(identifier: "ProfileContainerView")
        let projectsContainer = makeContainerView(identifier: "ProjectsContainerView")
        let reportsContainer = makeContainerView(identifier: "ReportsContainerView")
        let runningEntryContainer = makeContainerView(identifier: "RunningEntryContainer")

        self.profileActivityContainer = profileContainer
        self.projectsActivityContainer = projectsContainer
        self.reportsActivityContainer = reportsContainer
        self.runningEntryActivityContainer = runningEntryContainer

        rootStackView.addArrangedSubview(profileContainer)
        rootStackView.addArrangedSubview(projectsContainer)
        rootStackView.addArrangedSubview(reportsContainer)
        rootStackView.addArrangedSubview(runningEntryContainer)

        let activityStatuses = lastBinding.latestOutput { $0 }
        updateActivities <~ activityStatuses.combinePrevious([ActivityStatus]())
    }

    private func updateActivitiesState(from previousStatus: [ActivityStatus],
                                       to newStatus: [ActivityStatus]) {
        let previousStatusByActivity = Dictionary(uniqueKeysWithValues: previousStatus.map { ($0.activity, $0) })
        let newStatusByActivity = Dictionary(uniqueKeysWithValues: newStatus.map { ($0.activity, $0) })

        let previousActivities = Set(previousStatusByActivity.keys)
        let newActivities = Set(newStatusByActivity.keys)

        let activitiesToAdd = newActivities.subtracting(previousActivities)
        let activitiesToRemove = previousActivities.subtracting(newActivities)
        let activitiesToSwap = (newActivities.intersection(previousActivities)).filter {
            !previousStatusByActivity[$0]!.representedBySameController(as: newStatusByActivity[$0]!)
        }

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

    private func attachActivityView(_ activityView: NSView, to containerView: NSView) {
        activityView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(activityView)
        activityView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        activityView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        activityView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        activityView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        containerView.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            containerView.isHidden = false
            view.findRoot().layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    private func detachActivityView(_ activityView: NSView) {
        guard let containerView = activityView.superview else {
            return
        }

        NSAnimationContext.runAnimationGroup({ _ in
            containerView.isHidden = true
            view.findRoot().layoutSubtreeIfNeeded()
        }, completionHandler: {
            activityView.removeFromSuperview()
        })
    }

    private func swapActivityView(_ previousView: NSView, newView: NSView) {
        guard let superview = previousView.superview else {
            return
        }

        newView.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(newView)
        newView.isHidden = true
        newView.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
        newView.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
        newView.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
        newView.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
        newView.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup({ _ in
            newView.isHidden = false
            previousView.isHidden = true
            view.findRoot().layoutSubtreeIfNeeded()
        }, completionHandler: {
            previousView.removeFromSuperview()
        })
    }
}

private func makeContainerView(identifier: String) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.identifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

private func makeActivityController(for status: ActivityStatus) -> NSViewController {
    switch status {
    case .executing: return SyncingActivityViewController()
    case .succeeded: return ActivitySuccessViewController()
    case .error: return ActivityErrorViewController()
    }
}

fileprivate extension ActivityStatus {
    func representedBySameController(as anotherStatus: ActivityStatus) -> Bool {
        return (isExecuting == anotherStatus.isExecuting) &&
            (isSuccessful == anotherStatus.isSuccessful) &&
            (isError == anotherStatus.isError)
    }
}

fileprivate extension NSView {
    func findRoot() -> NSView {
        return superview?.findRoot() ?? self
    }
}
