//
//  ProjectCollectionViewHeader.swift
//  TogglTargets
//
//  Created by David Dávila on 17.04.17.
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

private let titleLabelTag = 1080

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
        if let label = viewWithTag(titleLabelTag) as? NSTextField {
            label.stringValue = title
        }
    }
}
