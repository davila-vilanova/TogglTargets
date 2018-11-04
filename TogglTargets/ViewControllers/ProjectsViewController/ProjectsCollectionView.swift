//
//  ProjectsCollectionView.swift
//  TogglTargets
//
//  Created by David Dávila on 19.09.18.
//  Copyright © 2018 davi.la. All rights reserved.
//

import Cocoa

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
            let headerAttrs = layoutAttributesForSupplementaryElement(ofKind: "UICollectionElementKindSectionHeader", at: IndexPath(item: 0, section: path.section)),
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
        guard selectionIndexPaths.count == 1,
            let currentSelection = selectionIndexPaths.first else {
                super.moveUp(sender)
                return
        }
        let newSelectionOrNil: IndexPath?
        if currentSelection.item > 0 {
            newSelectionOrNil = IndexPath(item: currentSelection.item - 1, section: currentSelection.section)
        } else if currentSelection.section > 0 {
            let newSection = currentSelection.section - 1
            newSelectionOrNil = IndexPath(item: numberOfItems(inSection: newSection) - 1, section: newSection)
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
        guard selectionIndexPaths.isEmpty,
            numberOfItems(inSection: 0) > 0 else {
                super.moveDown(sender)
                return
        }
        let newSelectionAsSetOfOne = Set([IndexPath(item: 0, section: 0)])
        selectItems(at: newSelectionAsSetOfOne, scrollPosition: [.nearestHorizontalEdge])
        delegate?.collectionView?(self, didSelectItemsAt: newSelectionAsSetOfOne)
    }
}
