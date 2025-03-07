//
//  ProjectsCollectionView.swift
//  TogglTargets
//
//  Created by David Dávila on 19.09.18.
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

/// An NSCollectionView that is modified to, when using a vertically scrolling flow layout:
/// * Not obscure items under its pinned headers when scrollToItems(at indexPaths: scrollPosition:) is invoked
/// * Select the correct items when moving up and down using keyboard navigation.
class ProjectsCollectionView: NSCollectionView {

    /// Modified to use a corrected scroll position if a header will be obscuring the item we are scrolling to
    override func scrollToItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
        func delegateToSuper() {
            super.scrollToItems(at: indexPaths, scrollPosition: scrollPosition)
        }

        guard let flowLayout = collectionViewLayout as? NSCollectionViewFlowLayout,
            flowLayout.sectionHeadersPinToVisibleBounds,
            flowLayout.scrollDirection == .vertical,
            let path = indexPaths.first,
            indexPaths.count == 1,
            scrollPosition.contains(.nearestHorizontalEdge),
            let selectedItemAttrs = layoutAttributesForItem(at: path),
            let headerAttrs = layoutAttributesForSupplementaryElement(ofKind: "UICollectionElementKindSectionHeader",
                                                                      at: IndexPath(item: 0, section: path.section)),
            let scrollView = enclosingScrollView else {
                delegateToSuper()
                return
        }

        let selectionFrame = selectedItemAttrs.frame
        let headerFrame = headerAttrs.frame
        let visibleRect = scrollView.documentVisibleRect

        func scrollToCorrectedPoint() {
            scroll(NSPoint(x: selectionFrame.origin.x, y: selectionFrame.origin.y - headerFrame.size.height))
        }

        if visibleRect.contains(selectionFrame) {
            if headerFrame.intersects(selectionFrame) { // header obscures item
                scrollToCorrectedPoint()
            } else {
                delegateToSuper()
            }
        } else {
            if selectionFrame.origin.y < visibleRect.origin.y { // item is above the visible rect
                scrollToCorrectedPoint()
            } else {
                delegateToSuper()
            }
        }
    }

    /// Modified to select the last item of the previous section
    /// when the selection before pressing the up arrow key is the first item of a section
    override func moveUp(_ sender: Any?) {
        guard let flowLayout = collectionViewLayout as? NSCollectionViewFlowLayout,
            flowLayout.scrollDirection == .vertical,
            selectionIndexPaths.count == 1,
            let currentSelection = selectionIndexPaths.first else {
                super.moveUp(sender)
                return
        }
        let newSelectionOrNil: IndexPath?
        if currentSelection.item > 0 {
            newSelectionOrNil = IndexPath(item: currentSelection.item - 1, section: currentSelection.section)
        } else if currentSelection.section > 0 {
            let newSection = currentSelection.section - 1
            newSelectionOrNil = numberOfItems(inSection: newSection) > 0 ?
                IndexPath(item: numberOfItems(inSection: newSection) - 1, section: newSection) : nil
        } else {
            newSelectionOrNil = nil
        }

        if let newSelection = newSelectionOrNil {
            deselectItems(at: selectionIndexPaths)
            delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
            let newSelectionAsSetOfOne = Set([newSelection])
            selectItems(at: newSelectionAsSetOfOne, scrollPosition: [.nearestHorizontalEdge])
            delegate?.collectionView?(self, didSelectItemsAt: newSelectionAsSetOfOne)
        }
    }

    /// Modified to select the first item when no item is selected previous to pressing the down arrow key
    override func moveDown(_ sender: Any?) {
        guard let flowLayout = collectionViewLayout as? NSCollectionViewFlowLayout,
            flowLayout.scrollDirection == .vertical,
            selectionIndexPaths.isEmpty,
            numberOfItems(inSection: 0) > 0 else {
                super.moveDown(sender)
                return
        }
        let newSelectionAsSetOfOne = Set([IndexPath(item: 0, section: 0)])
        selectItems(at: newSelectionAsSetOfOne, scrollPosition: [.nearestHorizontalEdge])
        delegate?.collectionView?(self, didSelectItemsAt: newSelectionAsSetOfOne)
    }
}
