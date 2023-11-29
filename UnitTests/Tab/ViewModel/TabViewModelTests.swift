//
//  TabViewModelTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

@MainActor
final class TabViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    // MARK: - Can reload

    func testWhenURLIsNilThenCanReloadIsFalse() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertFalse(tabViewModel.canReload)
    }

    func testWhenURLIsNotNilThenCanReloadIsTrue() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)

        let canReloadExpectation = expectation(description: "Can reload")
        tabViewModel.$canReload.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssert(tabViewModel.canReload)
            canReloadExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 2, handler: nil)
    }

    // MARK: - AddressBarString

    func testWhenURLIsNilThenAddressBarStringIsEmpty() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.addressBarString, "")
    }

    func testWhenURLIsSetThenAddressBarIsUpdated() {
        let urlString = "http://spreadprivacy.com"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion()

        tabViewModel.$addressBarString.debounce(for: 0.5, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsFileURLThenAddressBarIsFilePath() {
        let urlString = "file:///Users/Dax/file.txt"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion()
        
        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsDataURLThenAddressBarIsDataURL() {
        let urlString = "data:,Hello%2C%20World%21"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion()
        
        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarString, "data:")
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsBlobURLWithBasicAuthThenAddressBarStripsBasicAuth() {
        let urlStrings = ["blob:https://spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com",
                          "blob:ftp://another.spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com",
                          "blob:http://yetanother.spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com"]
        let expectedStarts = ["blob:https://", "blob:ftp://", "blob:http://"]
        let expectedNotContains = ["spoofed.domain.com", "another.spoofed.domain.com", "yetanother.spoofed.domain.com"]
        let uuidPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        let uuidRegex = try! NSRegularExpression(pattern: uuidPattern, options: [])

        for i in 0..<urlStrings.count {
            let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlStrings[i])!)
            let addressBarStringExpectation = expectation(description: "Address bar string")
            tabViewModel.simulateLoadingCompletion()

            tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
                XCTAssertTrue(tabViewModel.addressBarString.starts(with: expectedStarts[i]))
                XCTAssertTrue(tabViewModel.addressBarString.contains("attacker.com"))
                XCTAssertFalse(tabViewModel.addressBarString.contains(expectedNotContains[i]))
                let range = NSRange(location: 0, length: tabViewModel.addressBarString.utf16.count)
                let match = uuidRegex.firstMatch(in: tabViewModel.addressBarString, options: [], range: range)
                XCTAssertNotNil(match, "URL does not end with a GUID")
                addressBarStringExpectation.fulfill()
            } .store(in: &cancellables)
            waitForExpectations(timeout: 1, handler: nil)
        }
    }

    // MARK: - Title

    func testWhenURLIsNilThenTitleIsNewTab() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.title, "New Tab")
    }

    func testWhenTabTitleIsNotNilThenTitleReflectsTabTitle() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)
        let testTitle = "Test title"
        tabViewModel.tab.title = testTitle

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, testTitle)
            titleExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenTabTitleIsNilThenTitleIsAddressBarString() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, URL.duckDuckGo.host!)
            titleExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Favicon

    func testWhenContentIsNoneThenFaviconIsNil() {
        let tab = Tab(content: .none)
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.favicon, nil)
    }

    func testWhenContentIsHomeThenFaviconIsHome() {
        let tabViewModel = TabViewModel.aTabViewModel
        tabViewModel.tab.setContent(.homePage)

        let faviconExpectation = expectation(description: "Favicon")
        var fulfilled = false

        tabViewModel.$favicon.debounce(for: 0.1, scheduler: RunLoop.main).sink { favicon in
            guard favicon != nil else { return }
            if favicon == TabViewModel.Favicon.home,
                !fulfilled {
                faviconExpectation.fulfill()
                fulfilled = true
            }
        } .store(in: &cancellables)
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Zoom

    func testThatDefaultValueForTabsWebViewIsOne() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, DefaultZoomValue.percent100)
    }

    func testWhenAppearancePreferencesZoomLevelIsSetThenTabsWebViewZoomLevelIsUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab())
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        AppearancePreferences.shared.defaultPageZoom = randomZoomLevel

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    func testWhenAppearancePreferencesZoomLevelIsSetAndANewTabIsOpenThenItsWebViewHasTheLatestValueOfZoomLevel() {
        UserDefaultsWrapper<Any>.clearAll()
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        AppearancePreferences.shared.defaultPageZoom = randomZoomLevel

        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

}

extension TabViewModel {

    @MainActor
    static var aTabViewModel: TabViewModel {
        let tab = Tab()
        return TabViewModel(tab: tab)
    }

    @MainActor
    static func forTabWithURL(_ url: URL) -> TabViewModel {
        let tab = Tab(content: .url(url))
        return TabViewModel(tab: tab)
    }
    
    func simulateLoadingCompletion() {
        self.updateAddressBarStrings()
    }

}
