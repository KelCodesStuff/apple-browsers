//
//  TabSwitcherBarsStateHandler.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import UIKit

class TabSwitcherBarsStateHandler {

    let plusButton = UIBarButtonItem()
    let fireButton = UIBarButtonItem()
    let doneButton = UIBarButtonItem()
    let closeTabsButton = UIBarButtonItem()
    let menuButton = UIBarButtonItem()
    let addAllBookmarksButton = UIBarButtonItem()
    let tabSwitcherStyleButton = UIBarButtonItem()
    let editButton = UIBarButtonItem()
    let selectAllButton = UIBarButtonItem()
    let deselectAllButton = UIBarButtonItem()

    var bottomBarItems = [UIBarButtonItem]()
    var isBottomBarHidden = false
    var topBarLeftButtonItems = [UIBarButtonItem]()
    var topBarRightButtonItems = [UIBarButtonItem]()

    var interfaceMode: TabSwitcherViewController.InterfaceMode = .singleSelectNormal
    var selectedTabsCount: Int = 0
    var totalTabsCount: Int = 0
    var containsWebPages = false
    var canShowSelectionMenu = false

    func update(_ interfaceMode: TabSwitcherViewController.InterfaceMode,
                selectedTabsCount: Int,
                totalTabsCount: Int,
                containsWebPages: Bool) {

        guard interfaceMode != self.interfaceMode
                || selectedTabsCount != self.selectedTabsCount
                || totalTabsCount != self.totalTabsCount else {
            // If nothing has changed, don't update
            return
        }

        self.interfaceMode = interfaceMode
        self.selectedTabsCount = selectedTabsCount
        self.totalTabsCount = totalTabsCount
        self.containsWebPages = containsWebPages

        let canShowEditButton = self.totalTabsCount > 1 || containsWebPages
        
        updateBottomBar()
        updateTopLeftButtons(canShowEditButton: canShowEditButton)
        updateTopRightButtons(canShowEditButton: canShowEditButton)
    }

    func updateBottomBar() {
        switch interfaceMode {
        case .singleSelectNormal,
                .multiSelectAvailableNormal:
            bottomBarItems = [
                doneButton,
                UIBarButtonItem.flexibleSpace(),
                fireButton,
                UIBarButtonItem.flexibleSpace(),
                plusButton,
            ]
            isBottomBarHidden = false

        case .multiSelectEditingNormal:
            bottomBarItems = [
                closeTabsButton,
                UIBarButtonItem.flexibleSpace(),
                menuButton,
            ]
            isBottomBarHidden = false

        case .multiSelectedEditingLarge,
                .multiSelectAvailableLarge,
                .singleSelectLarge:
            bottomBarItems = []
            isBottomBarHidden = true
        }
    }

    func updateTopLeftButtons(canShowEditButton: Bool) {

        switch interfaceMode {
        case .singleSelectNormal:
            topBarLeftButtonItems = [
                addAllBookmarksButton,
            ]

        case .singleSelectLarge:
            topBarLeftButtonItems = [
                addAllBookmarksButton,
                tabSwitcherStyleButton,
            ]

        case .multiSelectAvailableNormal:
            topBarLeftButtonItems = [
                tabSwitcherStyleButton,
            ]

        case .multiSelectAvailableLarge:
            topBarLeftButtonItems = [
                canShowEditButton ? editButton : nil,
                tabSwitcherStyleButton,
            ].compactMap { $0 }

        case .multiSelectEditingNormal:
            topBarLeftButtonItems = [
                selectedTabsCount == totalTabsCount ? deselectAllButton : selectAllButton,
            ]

        case .multiSelectedEditingLarge:
            topBarLeftButtonItems = [
                doneButton,
            ]

        }
    }

    func updateTopRightButtons(canShowEditButton: Bool) {

        switch interfaceMode {
        case .singleSelectNormal:
            topBarRightButtonItems = [
                tabSwitcherStyleButton,
            ]

        case .singleSelectLarge, .multiSelectAvailableLarge:
            topBarRightButtonItems = [
                doneButton,
                fireButton,
                plusButton,
            ]

        case .multiSelectAvailableNormal:
            topBarRightButtonItems = [
                canShowEditButton ? editButton : nil,
            ].compactMap { $0 }

        case .multiSelectEditingNormal:
            topBarRightButtonItems = [
                doneButton,
            ]

        case .multiSelectedEditingLarge:
            topBarRightButtonItems = [
                menuButton,
            ]

        }
    }
}
