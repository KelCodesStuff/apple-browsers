//
//  CoreDataEncryptionTests.swift
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

import XCTest
import CryptoKit
@testable import DuckDuckGo_Privacy_Browser

class CoreDataEncryptionTests: XCTestCase {

    private lazy var mockValueTransformer: MockValueTransformer = {
        let name = NSValueTransformerName("MockValueTransformer")
        let transformer = MockValueTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)

        return transformer
    }()

    override func setUp() {
        super.setUp()

        mockValueTransformer.numberOfTransformations = 0
        try? EncryptedValueTransformer<NSString>.registerTransformer()
    }

    func testSavingEncryptedValues() {
        let container = createInMemoryPersistentContainer()
        let context = container.viewContext

        context.performAndWait {
            let entity = PartiallyEncryptedEntity(context: context)
            entity.date = Date()
            entity.encryptedString = "Hello, World" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }
    }

    func testFetchingEncryptedValues() {
        let container = createInMemoryPersistentContainer()
        let context = container.viewContext
        let timestamp = Date()

        context.performAndWait {
            let entity = PartiallyEncryptedEntity(context: context)
            entity.date = timestamp
            entity.encryptedString = "Hello, World" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }

        let result = firstPartiallyEncryptedEntity(context: context)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.date, timestamp)
        XCTAssertEqual(result?.encryptedString, "Hello, World" as NSString)
    }

    func testValueTransformers() {
        let transformer = self.mockValueTransformer
        let container = createInMemoryPersistentContainer()
        let context = container.viewContext

        context.performAndWait {
            let entity = MockEntity(context: context)
            entity.mockString = "Test String" as NSString

            do {
                try context.save()
            } catch {
                XCTFail("Failed with Core Data error: \(error)")
            }
        }

        XCTAssertEqual(transformer.numberOfTransformations, 1)

        let request = NSFetchRequest<NSManagedObject>(entityName: "MockEntity")

        do {
            let results = try context.fetch(request)
            let result = results[0] as? MockEntity
            XCTAssertEqual(result?.mockString, "Transformed: Test String" as NSString)
        } catch let error as NSError {
            XCTFail("Could not fetch encrypted entity: \(error), \(error.userInfo)")
        }
    }

    private func firstPartiallyEncryptedEntity(context: NSManagedObjectContext) -> PartiallyEncryptedEntity? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PartiallyEncryptedEntity")

        do {
            let results = try context.fetch(request)
            return results[0] as? PartiallyEncryptedEntity
        } catch let error as NSError {
            XCTFail("Could not fetch encrypted entity: \(error), \(error.userInfo)")
        }

        return nil
    }

    private func createInMemoryPersistentContainer() -> NSPersistentContainer {
        let modelName = "CoreDataEncryptionTesting"

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
