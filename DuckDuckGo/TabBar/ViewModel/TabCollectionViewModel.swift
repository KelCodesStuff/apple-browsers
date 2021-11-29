//
//  TabCollectionViewModel.swift
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
import Combine

protocol TabCollectionViewModelDelegate: AnyObject {

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel, selected: Bool)
    func tabCollectionViewModelDidInsert(_ tabCollectionViewModel: TabCollectionViewModel, at index: Int, selected: Bool)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removalIndex: Int,
                                andSelectTabAt selectionIndex: Int?)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didSelectAt selectionIndex: Int?)
    func tabCollectionViewModelDidMultipleChanges(_ tabCollectionViewModel: TabCollectionViewModel)

}

// swiftlint:disable type_body_length
final class TabCollectionViewModel: NSObject {

    weak var delegate: TabCollectionViewModelDelegate?

    private(set) var tabCollection: TabCollection

    var changesEnabled = true

    private var tabViewModels = [Tab: TabViewModel]()
    @Published private(set) var selectionIndex: Int? {
        didSet {
            updateSelectedTabViewModel()
        }
    }
    @Published private(set) var selectedTabViewModel: TabViewModel? {
        didSet {
            previouslySelectedTabViewModel = oldValue
        }
    }
    private weak var previouslySelectedTabViewModel: TabViewModel?

    @Published private(set) var canInsertLastRemovedTab: Bool = false

    // In a special occasion, we want to select the "parent" tab after closing the currently selected tab
    private var selectParentOnRemoval = false

    private var cancellables = Set<AnyCancellable>()

    init(tabCollection: TabCollection, selectionIndex: Int = 0) {
        self.tabCollection = tabCollection
        super.init()

        subscribeToTabs()
        subscribeToLastRemovedTab()

        if tabCollection.tabs.isEmpty {
            appendNewTab(with: .homepage)
        }
        if self.selectionIndex != selectionIndex {
            self.selectionIndex = selectionIndex
        }
    }

    convenience override init() {
        let tabCollection = TabCollection()
        self.init(tabCollection: tabCollection)
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    // MARK: - Selection

    @discardableResult func select(at index: Int, forceChange: Bool = false) -> Bool {
        guard changesEnabled || forceChange else { return false }
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = index
        selectParentOnRemoval = selectedTabViewModel === previouslySelectedTabViewModel && selectParentOnRemoval
        return true
    }

    func selectNext() {
        guard changesEnabled else { return }
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = (selectionIndex + 1) % tabCollection.tabs.count
            select(at: newSelectionIndex)
            delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex)
        } else {
            select(at: 0)
            delegate?.tabCollectionViewModel(self, didSelectAt: 0)
        }
    }

    func selectPrevious() {
        guard changesEnabled else { return }
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = selectionIndex - 1 >= 0 ? selectionIndex - 1 : tabCollection.tabs.count - 1
            select(at: newSelectionIndex)
            delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex)
        } else {
            select(at: tabCollection.tabs.count - 1)
            delegate?.tabCollectionViewModel(self, didSelectAt: tabCollection.tabs.count - 1)
        }
    }

    // MARK: - Addition

    func appendNewTab(with content: Tab.TabContent = .homepage, forceChange: Bool = false) {
        append(tab: Tab(content: content), selected: true)
    }

    func append(tab: Tab, selected: Bool = true, forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.append(tab: tab)

        if selected {
            select(at: tabCollection.tabs.count - 1, forceChange: forceChange)
            delegate?.tabCollectionViewModelDidAppend(self, selected: true)
        } else {
            delegate?.tabCollectionViewModelDidAppend(self, selected: false)
        }

        if selected {
            self.selectParentOnRemoval = true
        }
    }

    func append(tabs: [Tab]) {
        guard changesEnabled else { return }

        tabs.forEach {
            tabCollection.append(tab: $0)
        }
        let newSelectionIndex = tabCollection.tabs.count - 1
        select(at: newSelectionIndex)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func insert(tab: Tab, at index: Int = 0, selected: Bool = true) {
        guard changesEnabled else { return }

        tabCollection.insert(tab: tab, at: index)
        if selected {
            select(at: index)
        }
        delegate?.tabCollectionViewModelDidInsert(self, at: index, selected: selected)

        if selected {
            self.selectParentOnRemoval = true
        }
    }

    func insertChild(tab: Tab, selected: Bool) {
        guard changesEnabled else { return }
        guard let parentTab = tab.parentTab,
              let parentTabIndex = tabCollection.tabs.firstIndex(where: { $0 === parentTab }) else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        // Insert at the end of the child tabs
        var newIndex = parentTabIndex + 1
        while tabCollection.tabs[safe:newIndex]?.parentTab === parentTab { newIndex += 1 }
        insert(tab: tab, at: newIndex, selected: selected)
    }

    // MARK: - Removal

    func remove(at index: Int) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: index]?.parentTab
        guard tabCollection.remove(at: index) else { return }

        guard tabCollection.tabs.count > 0 else {
            selectionIndex = nil
            delegate?.tabCollectionViewModel(self, didRemoveTabAt: index, andSelectTabAt: nil)
            return
        }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        let newSelectionIndex: Int
        if selectionIndex == index,
           selectParentOnRemoval,
           let parentTab = parentTab,
           let parentTabIndex = tabCollection.tabs.firstIndex(of: parentTab) {
            // Select parent tab
            newSelectionIndex = parentTabIndex
        } else if selectionIndex == index,
                  let parentTab = parentTab,
                  let leftTab = tabCollection.tabs[safe: index - 1],
                  let rightTab = tabCollection.tabs[safe: index],
                  rightTab.parentTab !== parentTab && (leftTab.parentTab === parentTab || leftTab === parentTab) {
            // Select parent tab on left or another child tab on left instead of the tab on right
            newSelectionIndex = max(selectionIndex - 1, 0)
        } else if selectionIndex > index {
            newSelectionIndex = max(selectionIndex - 1, 0)
        } else {
            newSelectionIndex = max(min(selectionIndex, tabCollection.tabs.count - 1), 0)
        }
        select(at: newSelectionIndex)

        delegate?.tabCollectionViewModel(self, didRemoveTabAt: index, andSelectTabAt: newSelectionIndex)
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        guard changesEnabled else { return }

        tabCollection.removeAll(andAppend: exceptionIndex.map { tabCollection.tabs[$0] })

        if exceptionIndex != nil {
            select(at: 0)
        } else {
            selectionIndex = nil
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabs(after index: Int) {
        guard changesEnabled else { return }

        tabCollection.removeTabs(after: index)

        if !tabCollection.tabs.indices.contains(selectionIndex ?? -1) {
            selectionIndex = tabCollection.tabs.indices.last
        }
        
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeAllTabsAndAppendNew(forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.removeAll(andAppend: Tab(content: .homepage))
        select(at: 0, forceChange: forceChange)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabsAndAppendNew(at indexSet: IndexSet, forceChange: Bool = false) {
        guard !indexSet.isEmpty, changesEnabled || forceChange else { return }
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        tabCollection.removeTabs(at: indexSet)
        if tabCollection.tabs.isEmpty {
            tabCollection.append(tab: Tab(content: .homepage))
            select(at: 0, forceChange: forceChange)
        } else {
            let selectionDiff = indexSet.reduce(0) { result, index in
                if index < selectionIndex {
                    return result + 1
                } else {
                    return result
                }
            }

            select(at: max(min(selectionIndex - selectionDiff, tabCollection.tabs.count - 1), 0), forceChange: forceChange)
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func remove(ownerOf webView: WebView) {
        guard changesEnabled else { return }

        let webViews = tabCollection.tabs.map { $0.webView }
        guard let index = webViews.firstIndex(of: webView) else {
            os_log("TabCollection: Failed to get index of the tab", type: .error)
            return
        }

        self.remove(at: index)
    }

    func removeSelected() {
        guard changesEnabled else { return }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        self.remove(at: selectionIndex)
    }

    // MARK: - Others

    func putBackLastRemovedTab() {
        guard changesEnabled else { return }

        let lastRemovedTabIndex = tabCollection.lastRemovedTabCache?.index
        tabCollection.putBackLastRemovedTab()

        if let lastRemovedTabIndex = lastRemovedTabIndex {
            select(at: lastRemovedTabIndex)

            delegate?.tabCollectionViewModelDidInsert(self, at: lastRemovedTabIndex, selected: true)
        }
    }

    func duplicateTab(at index: Int) {
        guard changesEnabled else { return }

        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tab = tabCollection.tabs[index]
        let tabCopy = Tab(content: tab.content, sessionStateData: tab.sessionStateData)
        let newIndex = index + 1

        tabCollection.insert(tab: tabCopy, at: newIndex)
        select(at: newIndex)

        delegate?.tabCollectionViewModelDidInsert(self, at: newIndex, selected: true)
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard changesEnabled else { return }

        tabCollection.moveTab(at: index, to: newIndex)
        select(at: newIndex)

        delegate?.tabCollectionViewModel(self, didMoveTabAt: index, to: newIndex)
    }

    func replaceTab(at index: Int, with tab: Tab, forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.replaceTab(at: index, with: tab)

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }
        select(at: selectionIndex, forceChange: forceChange)
    }

    private func subscribeToTabs() {
        tabCollection.$tabs.sink { [weak self] newTabs in
            guard let self = self else { return }

            let new = Set(newTabs)
            let old = Set(self.tabViewModels.keys)

            self.removeTabViewModels(old.subtracting(new))
            self.addTabViewModels(new.subtracting(old))
        } .store(in: &cancellables)
    }

    private func subscribeToLastRemovedTab() {
        tabCollection.$lastRemovedTabCache.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanInsertLastRemovedTab()
        } .store(in: &cancellables)
    }

    private func removeTabViewModels(_ removed: Set<Tab>) {
        for tab in removed {
            tabViewModels[tab] = nil
        }
    }

    private func addTabViewModels(_ added: Set<Tab>) {
        for tab in added {
            tabViewModels[tab] = TabViewModel(tab: tab)
        }
    }

    private func updateSelectedTabViewModel() {
        guard let selectionIndex = selectionIndex else {
            selectedTabViewModel = nil
            return
        }
        let selectedTabViewModel = tabViewModel(at: selectionIndex)
        self.selectedTabViewModel = selectedTabViewModel
    }

    private func updateCanInsertLastRemovedTab() {
        canInsertLastRemovedTab = tabCollection.lastRemovedTabCache != nil
    }

}
// swiftlint:enable type_body_length
