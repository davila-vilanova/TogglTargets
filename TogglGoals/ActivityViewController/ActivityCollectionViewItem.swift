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

    override func loadView() {
        let stack = NSStackView()
        stack.autoresizingMask = .width
        stack.wantsLayer = true
        stack.layer?.backgroundColor = CGColor.init(red: 0.0, green: 0, blue: 0.8, alpha: 0.5)
        stack.orientation = .horizontal

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
//        let progress = NSProgressIndicator()
//        progress.isIndeterminate = true
//        progress.startAnimation(nil)
//        stackView.insertView(progress, at: 0, in: .leading)
//        stackView.addSubview(progress)

        let description = NSTextField(string: "Synchronizing \(activity.localizedName)")
        description.isBordered = false
        description.isEditable = false

        description.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
//        stackView.insertView(description, at: 0, in: .center)
        stackView.addSubview(description)
        stackView.layer!.backgroundColor = CGColor.init(red: 0.5, green: 0, blue: 0.0, alpha: 0.5)
    }

    private func displaySucceeded(_ activity: ActivityStatus.Activity) {
//        let image = NSImage(named: NSImage.Name("NSMenuOnStateTemplate"))!
//        let imageView = NSImageView(image: image)
//        imageView.imageScaling = .scaleProportionallyDown
//        stackView.insertView(imageView, at: 0, in: .leading)
//        stackView.addSubview(imageView)

        let description = NSTextField(string: "Synchronized \(activity.localizedName)")
        description.isBordered = false
        description.isEditable = false
        description.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
//        stackView.insertView(description, at: 0, in: .center)
        stackView.addSubview(description)
        stackView.layer!.backgroundColor = CGColor.init(red: 0.0, green: 0.5, blue: 0.0, alpha: 0.5)
    }

    private func displayError(_ error: APIAccessError, for activity: ActivityStatus.Activity, retry: RetryAction) {
        let image = NSImage(named: NSImage.Name("NSRefreshFreestandingTemplate"))!
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyDown
        stackView.insertView(imageView, at: 0, in: .leading)
        stackView.addSubview(imageView)
        stackView.layer!.backgroundColor = CGColor.init(red: 0.0, green: 0, blue: 0.0, alpha: 0.8)
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
