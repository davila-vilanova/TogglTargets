//
//  ProjectCollectionViewHeader.swift
//  TogglGoals
//
//  Created by David Dávila on 17.04.17.
//  Copyright © 2017 davi. All rights reserved.
//

import Cocoa

fileprivate let TitleLabelTag = 1080

class ProjectCollectionViewHeader: NSView, NSCollectionViewElement {

    var title: String? {
        didSet {
            displayTitle()
        }
    }

    override func awakeFromNib() {
        displayTitle()
    }

    private func displayTitle() {
        guard let title = title else {
            return
        }
        if let label = viewWithTag(TitleLabelTag) as? NSTextField {
            label.stringValue = title
        }
    }
}
