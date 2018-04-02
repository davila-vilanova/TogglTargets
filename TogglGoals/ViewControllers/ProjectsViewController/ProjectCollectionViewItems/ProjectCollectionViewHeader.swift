//
//  ProjectCollectionViewHeader.swift
//  TogglGoals
//
//  Created by David Dávila on 17.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

class ProjectCollectionViewHeader: NSView, NSCollectionViewElement {
    static let TitleLabelIdentifier = NSUserInterfaceItemIdentifier("titleLabel")

    var title: String = "" {
        didSet {
            displayTitle()
        }
    }
    
    private func displayTitle() {
        for view in subviews {
            if let label = view as? NSTextField,
                view.identifier == ProjectCollectionViewHeader.TitleLabelIdentifier {
                label.stringValue = title
            }
        }
    }
}