//
//  ViewController.swift
//  ActivityIteimViewTester
//
//  Created by David Davila on 20.03.18.
//  Copyright © 2018 David Dávila. All rights reserved.
//

import Cocoa
@testable import TogglGoals_MacOS

class ViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
    }

    private func configureCollectionView() {
        let layout = (collectionView.collectionViewLayout as! NSCollectionViewGridLayout)
        layout.maximumNumberOfColumns = 1

        collectionView.register(ActivityCollectionViewItem.self,
                                forItemWithIdentifier: NSUserInterfaceItemIdentifier("ActivityCollectionViewItem"))

        collectionView.content = [ActivityStatus.executing(.syncProfile)]


    }


}

