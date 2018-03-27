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

    override func loadView() {
        let view = NSView()
        view.autoresizingMask = .width
        view.wantsLayer = true
        if let layer = view.layer {
            layer.backgroundColor = CGColor.init(gray: 0.9, alpha: 1)
            layer.cornerRadius = 2
        }

        self.view = view
    }

    private var activityStatus: ActivityStatus? {
        didSet {
            if let unwrapped = self.activityStatus {
                displayActivityStatus(unwrapped)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        for subview in view.subviews {
            subview.removeFromSuperview()
        }
    }

    private func displayActivityStatus(_ status: ActivityStatus) {
        print("displayActivityStatus")

        switch status {
        case let .executing(activity): displayExecuting(activity)
        case let .succeeded(activity): displaySucceeded(activity)
        case let .error(activity, apiAccessError, retryAction):
            displayError(apiAccessError, for: activity, retry: retryAction)
        }
    }

    private func displayExecuting(_ activity: ActivityStatus.Activity) {
        print("displayExecuting")

        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.isIndeterminate = true
        progress.startAnimation(nil)

        view.addSubview(progress)

        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.heightAnchor.constraint(equalToConstant: 12).isActive = true
        progress.widthAnchor.constraint(equalTo: progress.heightAnchor).isActive = true
        progress.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8).isActive = true
        progress.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        let descriptionContainer = NSView()

        view.addSubview(descriptionContainer)

        descriptionContainer.translatesAutoresizingMaskIntoConstraints = false
        descriptionContainer.leadingAnchor.constraint(equalTo: progress.trailingAnchor, constant: 2).isActive = true
        descriptionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 2).isActive = true
        descriptionContainer.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        descriptionContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        let description = NSTextField(string: "Synchronizing \(activity.localizedName)")
        description.isBordered = false
        description.isEditable = false
        description.font = NSFont.systemFont(ofSize: 9)
        description.textColor = NSColor(cgColor: CGColor(gray: 0.2, alpha: 1))
        description.backgroundColor = NSColor.clear

        descriptionContainer.addSubview(description)

        description.translatesAutoresizingMaskIntoConstraints = false
        description.centerXAnchor.constraint(equalTo: descriptionContainer.centerXAnchor).isActive = true
        description.centerYAnchor.constraint(equalTo: descriptionContainer.centerYAnchor).isActive = true
    }

    private func displaySucceeded(_ activity: ActivityStatus.Activity) {
//        let image = NSImage(named: NSImage.Name("NSMenuOnStateTemplate"))!
//        let imageView = NSImageView(image: image)
//        imageView.imageScaling = .scaleProportionallyDown
//        stackView.insertView(imageView, at: 0, in: .leading)
//
//        let description = NSTextField(string: "Synchronized \(activity.localizedName)")
//        description.isBordered = false
//        description.isEditable = false
//        description.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
//        stackView.insertView(description, at: 0, in: .center)
    }

    private func displayError(_ error: APIAccessError, for activity: ActivityStatus.Activity, retry: RetryAction) {
//        let image = NSImage(named: NSImage.Name("NSRefreshFreestandingTemplate"))!
//        let imageView = NSImageView(image: image)
//        imageView.imageScaling = .scaleProportionallyDown
//        stackView.insertView(imageView, at: 0, in: .leading)
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
