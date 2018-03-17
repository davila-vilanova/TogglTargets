//
//  ActivityCollectionViewProgressItem.swift
//  TogglGoals
//
//  Created by David Dávila on 02.01.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

class ActivityCollectionViewItem: NSCollectionViewItem {

    override var representedObject: Any? {
        didSet {
            if let activityStatus = representedObject as? ActivityStatus {
                self.activityStatus = activityStatus
            }
        }
    }

    private var activityStatus: ActivityStatus? {
        didSet {
            if let unwrapped = self.activityStatus {
                displayActivityStatus(unwrapped)
            }
        }
    }

    private weak var heightConstraint: NSLayoutConstraint?

    override func loadView() {
        let stack = NSStackView()
        stack.autoresizingMask = .width
        stack.wantsLayer = true
        stack.layer?.backgroundColor = CGColor.init(gray: 0.9, alpha: 1)
        stack.orientation = .horizontal
        stack.translatesAutoresizingMaskIntoConstraints = false

//        let height = NSLayoutConstraint(item: stack,
//                                        attribute: .height,
//                                        relatedBy: .greaterThanOrEqual,
//                                        toItem: nil,
//                                        attribute: .height,
//                                        multiplier: 1,
//                                        constant: 30)
//
//        stack.addConstraint(height)
//        heightConstraint = height

        view = stack
    }

    private var stackView: NSStackView {
        return view as! NSStackView
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        for subview in stackView.subviews {
            subview.removeFromSuperview()
        }
    }

    private func displayActivityStatus(_ status: ActivityStatus) {
        switch status {
        case let .executing(activity): displayExecuting(activity)
        case let .succeeded(activity): displaySucceeded(activity)
        case let .error(activity, apiAccessError, retryAction):
            displayError(apiAccessError, for: activity, retry: retryAction)
        }
    }

    private func displayExecuting(_ activity: ActivityStatus.Activity) {
        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.isIndeterminate = true
        progress.startAnimation(nil)
        stackView.insertView(progress, at: 0, in: .leading)

        let description = NSTextField(string: "Synchronizing \(activity.localizedName)")
        description.isBordered = false
        description.isEditable = false

        description.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        stackView.insertView(description, at: 0, in: .center)
    }

    private func displaySucceeded(_ activity: ActivityStatus.Activity) {
        let image = NSImage(named: NSImage.Name("NSMenuOnStateTemplate"))!
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyDown
        stackView.insertView(imageView, at: 0, in: .leading)

        let description = NSTextField(string: "Synchronized \(activity.localizedName)")
        description.isBordered = false
        description.isEditable = false
        description.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        stackView.insertView(description, at: 0, in: .center)
    }

    private func displayError(_ error: APIAccessError, for activity: ActivityStatus.Activity, retry: RetryAction) {
        let image = NSImage(named: NSImage.Name("NSRefreshFreestandingTemplate"))!
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyDown
        stackView.insertView(imageView, at: 0, in: .leading)
    }
}

fileprivate extension ActivityStatus.Activity {
    var localizedName: String {
        switch self {
        case .syncProfile: return "profile"
        case .syncProjects: return "projects"
        case .syncReports: return "reports"
        case .syncRunningEntry: return "running entry"
        }
    }
}
