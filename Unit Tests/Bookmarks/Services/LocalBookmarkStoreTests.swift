//
//  BookmarkStoreTests.swift
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

import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class LocalBookmarkStoreTests: XCTestCase {

    func testWhenBookmarkIsSaved_ThenItMustBeLoadedFromStore() {
        let container = createInMemoryPersistentContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(url: URL.duckDuckGo, title: "DuckDuckGo", favicon: nil, isFavorite: true, managedObjectId: nil)
        bookmarkStore.save(bookmark: bookmark) { (success, managedObjectId, error) in
            XCTAssert(success)
            XCTAssertNotNil(managedObjectId)
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmarkStore.loadAll { bookmarks, error in
                XCTAssertNotNil(bookmarks)
                XCTAssertNil(error)
                XCTAssert(bookmarks?.count == 1)
                XCTAssert(bookmarks?.first == bookmark)

                loadingExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    func testWhenBookmarkIsRemoved_ThenItShouldntBeLoadedFromStore() {
        let container = createInMemoryPersistentContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let removingExpectation = self.expectation(description: "Removing")
        let loadingExpectation = self.expectation(description: "Loading")

        var bookmark = Bookmark(url: URL.duckDuckGo, title: "DuckDuckGo", favicon: nil, isFavorite: true, managedObjectId: nil)
        bookmarkStore.save(bookmark: bookmark) { (success, managedObjectId, error) in
            XCTAssert(success)
            XCTAssertNotNil(managedObjectId)
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmark.managedObjectId = managedObjectId

            bookmarkStore.remove(bookmark: bookmark) { (success, error) in
                XCTAssert(success)
                XCTAssertNil(error)

                removingExpectation.fulfill()

                bookmarkStore.loadAll { bookmarks, error in
                    XCTAssertNotNil(bookmarks)
                    XCTAssertNil(error)
                    XCTAssert(bookmarks?.count == 0)

                    loadingExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    private func createInMemoryPersistentContainer() -> NSPersistentContainer {
        let modelName = "Bookmark"

        guard let modelURL = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let objectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing object model from: \(modelURL)")
        }

        let container = NSPersistentContainer(name: modelName, managedObjectModel: objectModel)

        // Creates a persistent store using the in-memory model, no state will be written to disk.
        // This was the approach I had seen recommended in a WWDC session, but there is also a
        // `NSInMemoryStoreType` option for doing this.
        //
        // This approach is apparently the recommended choice: https://www.donnywals.com/setting-up-a-core-data-store-for-unit-tests/
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores(completionHandler: { _, error in
          if let error = error as NSError? {
            fatalError("Failed to load stores: \(error), \(error.userInfo)")
          }
        })

        return container
    }

}
