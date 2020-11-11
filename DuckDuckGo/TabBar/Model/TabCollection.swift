//
//  TabCollection.swift
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

import Foundation
import os.log

protocol TabCollectionDelegate: AnyObject {

    func tabCollection(_ tabCollection: TabCollection, didAppend tab: Tab)
    func tabCollection(_ tabCollection: TabCollection, didInsert tab: Tab, at index: Int)
    func tabCollection(_ tabCollection: TabCollection, didRemoveTabAt index: Int)
    func tabCollection(_ tabCollection: TabCollection, didRemoveAllAndAppend tab: Tab)
    func tabCollection(_ tabCollection: TabCollection, didMoveTabAt index: Int, to newIndex: Int)

}

class TabCollection {

    @Published private(set) var tabs: [Tab] = []
    weak var delegate: TabCollectionDelegate?

    @Published private(set) var lastRemovedTabCache: (url: URL?, index: Int)?

    func append(tab: Tab) {
        tabs.append(tab)
        delegate?.tabCollection(self, didAppend: tab)
    }

    func insert(tab: Tab, at index: Int) {
        guard index >= 0, index <= tabs.endIndex else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        tabs.insert(tab, at: index)
        delegate?.tabCollection(self, didInsert: tab, at: index)
    }

    func remove(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return false
        }

        saveLastRemovedTab(at: index)
        tabs.remove(at: index)

        delegate?.tabCollection(self, didRemoveTabAt: index)

        return true
    }

    func removeAllAndAppend(tab: Tab) {
        tabs.removeAll()
        tabs.insert(tab, at: 0)
        delegate?.tabCollection(self, didRemoveAllAndAppend: tab)
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard index >= 0, index < tabs.count, newIndex >= 0, newIndex < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        if index == newIndex { return }
        if abs(index - newIndex) == 1 {
            tabs.swapAt(index, newIndex)
            delegate?.tabCollection(self, didMoveTabAt: index, to: newIndex)
            return
        }

        var tabs = self.tabs
        tabs.insert(tabs.remove(at: index), at: newIndex)
        self.tabs = tabs
        delegate?.tabCollection(self, didMoveTabAt: index, to: newIndex)
    }

    func saveLastRemovedTab(at index: Int) {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        let tab = tabs[index]
        lastRemovedTabCache = (tab.url, index)
    }

    func insertLastRemovedTab() {
        guard let lastRemovedTabCache = lastRemovedTabCache else {
            os_log("TabCollection: No tab removed yet", type: .error)
            return
        }

        let tab = Tab()
        tab.url = lastRemovedTabCache.url
        insert(tab: tab, at: min(lastRemovedTabCache.index, tabs.count))
        self.lastRemovedTabCache = nil
    }

}
