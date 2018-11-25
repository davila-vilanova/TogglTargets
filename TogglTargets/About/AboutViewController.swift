//
//  AboutViewController.swift
//  TogglTargets
//
//  Created by David Dávila on 04.11.18.
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

class AboutViewController: NSViewController {

    @IBOutlet weak var versionLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        let empty = ""
        let shortVersionString =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? empty
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? empty
        versionLabel.stringValue = "\(shortVersionString) (\(versionString))"
    }

}
