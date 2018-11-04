//
//  AboutViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 04.11.18.
//  Copyright © 2018 davi. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    
    @IBOutlet weak var versionLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let empty = ""
        let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? empty
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? empty
        versionLabel.stringValue = "\(shortVersionString) (\(versionString))"
    }
    
}
