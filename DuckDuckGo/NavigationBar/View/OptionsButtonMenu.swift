//
//  OptionsButtonMenuDelegate.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log
import WebKit

class OptionsButtonMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel

    required init(coder: NSCoder) {
        fatalError("OptionsButtonMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init(title: "")

        setupMenuItems()
    }

    private func setupMenuItems() {
        let moveTabMenuItem = NSMenuItem(title: "Move Tab to New Window",
                                         action: #selector(moveTabToNewWindowAction(_:)),
                                         keyEquivalent: "")
        moveTabMenuItem.target = self
        moveTabMenuItem.image = NSImage(named: "MoveTabToNewWindow")
        addItem(moveTabMenuItem)
    }

    @objc func moveTabToNewWindowAction(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        let url = selectedTabViewModel.tab.url
        tabCollectionViewModel.removeSelected()
        WindowsManager.openNewWindow(with: url)
    }
}
