//
//  TabCollectionViewModelTests+WithoutPinnedTabsManager.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

// MARK: - Tests for TabCollectionViewModel without PinnedTabsManager (popup windows)

extension TabCollectionViewModelTests {

    // MARK: - TabViewModel

    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledWithIndexOutOfBoundsThenNilIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertNil(tabCollectionViewModel.tabViewModel(at: 1))
    }

    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledThenAppropriateTabViewModelIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertEqual(tabCollectionViewModel.tabViewModel(at: 0)?.tab,
                       tabCollectionViewModel.tabCollection.tabs[0])
    }

    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledWithSameIndexThenTheResultHasSameIdentity() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.tabViewModel(at: 0) === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenTabViewModelIsInitializedWithoutTabsThenNewHomePageTabIsCreated() {
        let tabCollection = TabCollection()
        XCTAssertTrue(tabCollection.tabs.isEmpty)

        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection())

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs[0].content, .homePage)
    }

    // MARK: - Select

    func test_WithoutPinnedTabsManager_WhenTabCollectionViewModelIsInitializedThenSelectedTabViewModelIsFirst() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.select(at: .unpinned(1))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)

        tabCollectionViewModel.select(at: .pinned(0))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }

    func test_WithoutPinnedTabsManager_WhenSelectionIndexPointsToTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenSelectNextIsCalledThenNextTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    func test_WithoutPinnedTabsManager_WhenLastTabIsSelectedThenSelectNextChangesSelectionToFirstOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenSelectPreviousIsCalledThenPreviousTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenFirstTabIsSelectedThenSelectPreviousChangesSelectionToLastOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenSelectDisplayableTabIfPresentSelectsPreferencesTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .anyPreferencePane))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.anyPreferencePane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenOpeningPreferencesWithDifferentPaneUpdatesPaneOnExistingTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .preferences(pane: .appearance)))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.preferences(pane: .privacy)))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab.content, .preferences(pane: .privacy))
    }

    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenOpeningPreferencesWithAnyPaneDoesNotUpdatePaneOnExistingTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .preferences(pane: .appearance)))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.anyPreferencePane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab.content, .preferences(pane: .appearance))
    }

    func test_WithoutPinnedTabsManager_WhenBookmarksTabIsPresentThenSelectDisplayableTabIfPresentSelectsBookmarksTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .bookmarks))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.bookmarks))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    func test_WithoutPinnedTabsManager_SelectDisplayableTabDoesNotChangeSelectionIfDisplayableTabIsNotPresent() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))
        tabCollectionViewModel.select(at: .unpinned(2))

        XCTAssertFalse(tabCollectionViewModel.selectDisplayableTabIfPresent(.bookmarks))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 2))
    }

    func test_WithoutPinnedTabsManager_SelectDisplayableTabDoesNotChangeSelectionIfDisplayableTabTypeDoesNotMatch() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .bookmarks))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .homePage))
        tabCollectionViewModel.select(at: .unpinned(2))

        XCTAssertFalse(tabCollectionViewModel.selectDisplayableTabIfPresent(.anyPreferencePane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 2))
    }

    // MARK: - Append

    func test_WithoutPinnedTabsManager_WhenAppendNewTabIsCalledThenNewTabIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.appendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))
    }

    func test_WithoutPinnedTabsManager_WhenTabIsAppendedWithSelectedAsFalseThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel

        tabCollectionViewModel.append(tab: Tab(), selected: false)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === selectedTabViewModel)
    }

    func test_WithoutPinnedTabsManager_WhenTabIsAppendedWithSelectedAsTrueThenNewTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.append(tab: Tab(), selected: true)
        let lastTabViewModel = tabCollectionViewModel.tabViewModel(at: tabCollectionViewModel.tabCollection.tabs.count - 1)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === lastTabViewModel)
    }

    func test_WithoutPinnedTabsManager_WhenMultipleTabsAreAppendedThenTheLastOneIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let lastTab = Tab()
        tabCollectionViewModel.append(tabs: [Tab(), lastTab])

        XCTAssert(tabCollectionViewModel.selectedTabViewModel?.tab === lastTab)
    }

    // MARK: - Insert

    func test_WithoutPinnedTabsManager_WhenInsertChildAndParentIsNil_ThenNoChildIsInserted() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let tab = Tab()
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab !== tabCollectionViewModel.tabViewModel(at: 0)?.tab)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 1)
    }

    func test_WithoutPinnedTabsManager_WhenInsertChildAndParentIsntPartOfTheTabCollection_ThenNoChildIsInserted() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        let tab = Tab(content: .none, parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab !== tabCollectionViewModel.tabViewModel(at: 0)?.tab)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 1)
    }

    func test_WithoutPinnedTabsManager_WhenInsertChildAndNoOtherChildTabIsNearParent_ThenTabIsInsertedRightNextToParent() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        tabCollectionViewModel.append(tab: parentTab)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    func test_WithoutPinnedTabsManager_WhenInsertChildAndOtherChildTabsAreNearParent_ThenTabIsInsertedAtTheEndOfChildList() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(tab: parentTab, at: .unpinned(1), selected: true)

        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: true)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 5)?.tab)
    }

    func test_WithoutPinnedTabsManager_WhenInsertChildAndParentIsLast_ThenTabIsAppendedAtTheEnd() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(tab: parentTab, at: .unpinned(1), selected: true)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    // MARK: - Remove

    func test_WithoutPinnedTabsManager_WhenRemoveIsCalledWithIndexOutOfBoundsThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
    }

    func test_WithoutPinnedTabsManager_WhenTabIsRemovedAndSelectedTabHasHigherIndexThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.remove(at: .unpinned(0))

        XCTAssertEqual(selectedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func test_WithoutPinnedTabsManager_WhenSelectedTabIsRemovedThenNextItemWithLowerIndexIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func test_WithoutPinnedTabsManager_WhenAllOtherTabsAreRemovedThenRemainedIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.removeAllTabs(except: 0)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func test_WithoutPinnedTabsManager_WhenLastTabIsRemoved_ThenSelectionIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: .unpinned(0))

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
    }

    func test_WithoutPinnedTabsManager_WhenNoTabIsSelectedAndTabIsRemoved_ThenSelectionStaysEmpty() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        // Clear selection
        tabCollectionViewModel.select(at: .unpinned(-1))

        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
    }

    func test_WithoutPinnedTabsManager_WhenChildTabIsInsertedAndRemoved_ThenParentIsSelectedBack() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let parentTab = tabCollectionViewModel.tabCollection.tabs[0]
        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)

        tabCollectionViewModel.remove(at: .unpinned(2))

        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, parentTab)
    }

    func test_WithoutPinnedTabsManager_WhenChildTabOnLeftHasTheSameParentAndTabOnRightDont_ThenTabOnLeftIsSelectedAfterRemoval() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let parentTab = tabCollectionViewModel.tabCollection.tabs[0]
        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)
        tabCollectionViewModel.appendNewTab()

        // Select and remove childTab2
        tabCollectionViewModel.selectPrevious()
        tabCollectionViewModel.removeSelected()

        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, childTab1)
    }

    func test_WithoutPinnedTabsManager_WhenOwnerOfWebviewIsRemovedThenAllOtherTabsRemained() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let lastTabViewModel = tabCollectionViewModel.tabViewModel(at: tabCollectionViewModel.tabCollection.tabs.count - 1)!

        tabCollectionViewModel.remove(ownerOf: lastTabViewModel.tab.webView)

        XCTAssertFalse(tabCollectionViewModel.tabCollection.tabs.contains(lastTabViewModel.tab))
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 2)
    }

    func test_WithoutPinnedTabsManager_WhenOwnerOfWebviewIsNotInTabCollectionThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let originalCount = tabCollectionViewModel.tabCollection.tabs.count
        let tab = Tab()

        tabCollectionViewModel.remove(ownerOf: tab.webView)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, originalCount)
    }

    func test_WithoutPinnedTabsManager_RemoveSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.removeSelected()

        XCTAssertFalse(tabCollectionViewModel.tabCollection.tabs.contains(selectedTab!))
    }

    // MARK: - Duplicate

    func test_WithoutPinnedTabsManager_WhenTabIsDuplicatedThenItsCopyHasHigherIndexByOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)

        tabCollectionViewModel.duplicateTab(at: .unpinned(0))

        XCTAssert(firstTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithoutPinnedTabsManager_WhenTabIsDuplicatedThenItsCopyHasTheSameUrl() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)
        firstTabViewModel?.tab.url = URL.duckDuckGo

        tabCollectionViewModel.duplicateTab(at: .unpinned(0))

        XCTAssertEqual(firstTabViewModel?.tab.url, tabCollectionViewModel.tabViewModel(at: 1)?.tab.url)
    }

}

fileprivate extension TabCollectionViewModel {

    static func aTabCollectionViewModel() -> TabCollectionViewModel {
        let tabCollection = TabCollection()
        return TabCollectionViewModel(tabCollection: tabCollection, pinnedTabsManager: nil)
    }
}
