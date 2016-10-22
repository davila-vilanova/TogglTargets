//
//  ProjectCollectionViewItem.swift
//  TogglGoals
//
//  Created by David Davila on 22/10/2016.
//  Copyright © 2016 davi. All rights reserved.
//

import Cocoa

class ProjectCollectionViewItem: NSCollectionViewItem
{
    @IBOutlet weak var projectNameLabel: NSTextField!

    var projectName: String? {
        didSet {
            if isViewLoaded {
                let value: String
                if let name = projectName {
                    value = name
                } else {
                    value = "---"
                }
                projectNameLabel.stringValue = value
            }
        }
    }

    override var textField: NSTextField? {
        get {
            return projectNameLabel
        }
        set { }
    }

    override var isSelected: Bool {
        set {
            let selected = newValue
            super.isSelected = selected

            let color = selected ? NSColor.controlHighlightColor : NSColor.clear
            self.view.layer?.backgroundColor = color.cgColor
        }

        get {
            return super.isSelected
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let name = projectName {
            projectNameLabel.stringValue = name
        }
    }
}
