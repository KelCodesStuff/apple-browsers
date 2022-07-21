//
//  WindowManagerStateRestorationTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class WindowManagerStateRestorationTests: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
        WindowsManager.closeWindows()
    }

    func isTab(_ a: Tab, equalTo b: Tab) -> Bool {
        a.url == b.url
            && a.title == b.title
            && a.sessionStateData == b.sessionStateData
            && a.webView.configuration.websiteDataStore.isPersistent == b.webView.configuration.websiteDataStore.isPersistent
    }
    func areTabsEqual(_ a: [Tab], _ b: [Tab]) -> Bool {
        a.count == b.count &&
            !a.enumerated().contains { !isTab($0.1, equalTo: b[$0.0]) }
    }
    func areTabCollectionViewModelsEqual(_ a: TabCollectionViewModel, _ b: TabCollectionViewModel) -> Bool {
        a.selectionIndex == b.selectionIndex && areTabsEqual(a.tabCollection.tabs, b.tabCollection.tabs)
    }

    // MARK: -

    // swiftlint:disable:next function_body_length
    func testWindowManagerStateRestoration() throws {
        let tabs1 = [
            Tab(content: .url(URL(string: "https://duckduckgo.com")!),
                title: "DDG",
                error: nil,
                sessionStateData: "data".data(using: .utf8)!),
            Tab(),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=search&t=osx&ia=web")!),
                title: "DDG search",
                error: nil,
                sessionStateData: "data 2".data(using: .utf8)!)
        ]
        let tabs2 = [
            Tab(),
            Tab(),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=another_search&t=osx&ia=web")!),
                title: "DDG search",
                error: nil,
                sessionStateData: "data 3".data(using: .utf8)!)
        ]
        let pinnedTabs = [
            Tab(content: .url(URL(string: "https://duck.com")!)),
            Tab(content: .url(URL(string: "https://wikipedia.org")!)),
            Tab(content: .url(URL(string: "https://duckduckgo.com/?q=search_in_pinned_tab&t=osx&ia=web")!),
                title: "DDG search",
                error: nil,
                sessionStateData: "data 4".data(using: .utf8)!)
        ]

        WindowControllersManager.shared.pinnedTabsManager.setUp(with: .init(tabs: pinnedTabs))
        let model1 = TabCollectionViewModel(tabCollection: TabCollection(tabs: tabs1), selectionIndex: 0)
        let model2 = TabCollectionViewModel(tabCollection: TabCollection(tabs: tabs2), selectionIndex: 2)
        WindowsManager.openNewWindow(with: model1)
        WindowsManager.openNewWindow(with: model2)
        WindowControllersManager.shared.lastKeyMainWindowController = WindowControllersManager.shared.mainWindowControllers[1]

        let state = WindowManagerStateRestoration(windowControllersManager: WindowControllersManager.shared)
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        state.encode(with: archiver)
        let data = archiver.encodedData

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        guard let restored = WindowManagerStateRestoration(coder: unarchiver) else {
            return XCTFail("Could not unarchive WindowManagerStateRestoration")
        }

        XCTAssertTrue(areTabsEqual(restored.pinnedTabs!.tabs, pinnedTabs))
        XCTAssertEqual(restored.windows.count, 2)
        XCTAssertEqual(restored.keyWindowIndex, 1)
        for (idx, window) in state.windows.enumerated() {
            XCTAssertTrue(areTabCollectionViewModelsEqual(window.model,
                                                          state.windows[idx].model))
            XCTAssertEqual(window.frame, state.windows[idx].frame)
            XCTAssertEqual(window.model.pinnedTabs, pinnedTabs)
        }
    }

}
