//
//  Database.swift
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

import BrowserServicesKit
import Foundation
import CoreData
import Persistence

final class Database {

    fileprivate struct Constants {
        static let databaseName = "Database"
    }

    static let shared: CoreDataDatabase = {
        let (database, error) = makeDatabase()
        if database == nil {
            firePixelErrorIfNeeded(error: error)
            NSAlert.databaseFactoryFailed().runModal()
            NSApp.terminate(nil)
        }

        return database!
    }()

    static func makeDatabase() -> (CoreDataDatabase?, Error?) {
        func makeDatabase(keyStore: EncryptionKeyStoring, containerLocation: URL) -> (CoreDataDatabase?, Error?) {
            do {
                try EncryptedValueTransformer<NSImage>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSString>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSURL>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSNumber>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSError>.registerTransformer(keyStore: keyStore)
                try EncryptedValueTransformer<NSData>.registerTransformer(keyStore: keyStore)
            } catch {
                return (nil, error)
            }
            let mainModel = NSManagedObjectModel.mergedModel(from: [.main])!
            let httpsUpgradeModel = HTTPSUpgrade.managedObjectModel

            return (CoreDataDatabase(name: Constants.databaseName,
                                     containerLocation: containerLocation,
                                     model: .init(byMerging: [mainModel, httpsUpgradeModel])!), nil)
        }
#if DEBUG
        assert(![.unitTests, .xcPreviews].contains(NSApp.runType), "Use CoreData.---Container() methods for testing purposes")
#endif

        let keyStore: EncryptionKeyStoring
        let containerLocation: URL
#if CI
        keyStore = (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
        containerLocation = FileManager.default.temporaryDirectory
#else
        keyStore = EncryptionKeyStore(generator: EncryptionKeyGenerator())
        containerLocation = URL.sandboxApplicationSupportURL
#endif

        return makeDatabase(keyStore: keyStore, containerLocation: containerLocation)
    }

    // MARK: - Pixel

    @UserDefaultsWrapper(key: .lastDatabaseFactoryFailurePixelDate, defaultValue: nil)
    static var lastDatabaseFactoryFailurePixelDate: Date?

    static func firePixelErrorIfNeeded(error: Error?) {
        let lastPixelSentAt = lastDatabaseFactoryFailurePixelDate ?? Date.distantPast

        // Fire the pixel once a day at max
        if lastPixelSentAt < Date.daysAgo(1) {
            lastDatabaseFactoryFailurePixelDate = Date()
            Pixel.fire(.debug(event: .dbMakeDatabaseError, error: error))
        }
    }
}

extension Array where Element == CoreDataErrorsParser.ErrorInfo {

    var errorPixelParameters: [String: String] {
        let params: [String: String]
        if let first = first {
            params = ["errorCount": "\(count)",
                      "coreDataCode": "\(first.code)",
                      "coreDataDomain": first.domain,
                      "coreDataEntity": first.entity ?? "empty",
                      "coreDataAttribute": first.property ?? "empty"]
        } else {
            params = ["errorCount": "\(count)"]
        }
        return params
    }
}

extension NSManagedObjectContext {

    func save(onErrorFire event: Pixel.Event.Debug) throws {
        do {
            try save()
        } catch {
            let nsError = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: nsError)

            Pixel.fire(.debug(event: event, error: error),
                       withAdditionalParameters: processedErrors.errorPixelParameters)

            throw error
        }
    }
}
