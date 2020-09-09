//
//  MainMenuActions.swift
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

// MARK: - Main Menu Actions

// Extension of MainViewController because actions are sent to objects of responder chain
extension MainViewController {

    @IBAction func newWindow(_ sender: Any?) {
        WindowsManager.openNewWindow()
    }

    @IBAction func closeAllWindows(_ sender: Any?) {
        WindowsManager.closeAllWindows()
    }

    @IBAction func newTab(_ sender: Any?) {
        tabCollectionViewModel.appendNewTab()
    }

    @IBAction func closeTab(_ sender: Any?) {
        tabCollectionViewModel.removeSelected()
    }

    @IBAction func reloadPage(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        selectedTabViewModel.tab.reload()
    }

    @IBAction func stopLoading(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        selectedTabViewModel.tab.stopLoading()
    }

    @IBAction func back(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func forward(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        selectedTabViewModel.tab.goForward()
    }

    @IBAction func home(_ sender: Any?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", log: OSLog.Category.general, type: .error)
            return
        }

        selectedTabViewModel.tab.goHome()
    }

    @IBAction func reopenLastClosedTab(_ sender: Any?) {
        tabCollectionViewModel.insertLastRemovedTab()
    }

}
