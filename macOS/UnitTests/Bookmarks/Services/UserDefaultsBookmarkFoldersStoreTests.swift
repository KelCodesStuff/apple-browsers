//
//  UserDefaultsBookmarkFoldersStoreTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class UserDefaultsBookmarkFoldersStoreTests: XCTestCase {
    private static let suiteName = "testing_bookmark_folders_store"
    private var userDefaults: UserDefaults!
    private var sut: UserDefaultsBookmarkFoldersStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults(suiteName: Self.suiteName)
        sut = UserDefaultsBookmarkFoldersStore(keyValueStore: userDefaults)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        userDefaults = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testReturnBookmarkAllTabsLastFolderIdUsedWhenUserDefaultsContainsValue() {
        // GIVEN
        let value = "12345"
        userDefaults.set(value, forKey: UserDefaultsBookmarkFoldersStore.Keys.bookmarkAllTabsFolderUsedKey)

        // WHEN
        let result = sut.lastBookmarkAllTabsFolderIdUsed

        // THEN
        XCTAssertEqual(result, value)
    }

    func testReturnNilForBookmarkAllTabsLastFolderIdUsedWhenUserDefaultsDoesNotContainValue() {
        // GIVEN
        userDefaults.set(nil, forKey: UserDefaultsBookmarkFoldersStore.Keys.bookmarkAllTabsFolderUsedKey)

        // WHEN
        let result = sut.lastBookmarkAllTabsFolderIdUsed

        // THEN
        XCTAssertNil(result)
    }

    func testReturnBookmarkSingleTabLastFolderIdUsedWhenUserDefaultsContainsValue() {
        // GIVEN
        let value = "12345"
        userDefaults.set(value, forKey: UserDefaultsBookmarkFoldersStore.Keys.bookmarkSingleTabFolderUsedKey)

        // WHEN
        let result = sut.lastBookmarkSingleTabFolderIdUsed

        // THEN
        XCTAssertEqual(result, value)
    }

    func testReturnNilForBookmarkSingleTabLastFolderIdUsedWhenUserDefaultsDoesNotContainValue() {
        // GIVEN
        userDefaults.set(nil, forKey: UserDefaultsBookmarkFoldersStore.Keys.bookmarkSingleTabFolderUsedKey)

        // WHEN
        let result = sut.lastBookmarkSingleTabFolderIdUsed

        // THEN
        XCTAssertNil(result)
    }
}
