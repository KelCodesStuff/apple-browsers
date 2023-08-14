//
//  SyncDataProviders.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Common
import DDGSync
import Persistence
import SyncDataProviders

final class SyncDataProviders: DataProvidersSource {
    public let bookmarksAdapter: SyncBookmarksAdapter
    public let credentialsAdapter: SyncCredentialsAdapter

    func makeDataProviders() -> [DataProviding] {
        initializeMetadataDatabaseIfNeeded()
        guard let syncMetadata else {
            assertionFailure("Sync Metadata not initialized")
            return []
        }

        bookmarksAdapter.setUpProviderIfNeeded(database: bookmarksDatabase, metadataStore: syncMetadata)
        credentialsAdapter.setUpProviderIfNeeded(secureVaultFactory: secureVaultFactory, metadataStore: syncMetadata)

        let providers: [Any] = [
            bookmarksAdapter.provider as Any,
            credentialsAdapter.provider as Any
        ]

        return providers.compactMap { $0 as? DataProviding }
    }

    init(bookmarksDatabase: CoreDataDatabase, secureVaultFactory: AutofillVaultFactory = AutofillSecureVaultFactory) {
        self.bookmarksDatabase = bookmarksDatabase
        self.secureVaultFactory = secureVaultFactory
        bookmarksAdapter = SyncBookmarksAdapter()
        credentialsAdapter = SyncCredentialsAdapter(secureVaultFactory: secureVaultFactory)
    }

    private func initializeMetadataDatabaseIfNeeded() {
        guard !isSyncMetadaDatabaseLoaded else {
            return
        }

        syncMetadataDatabase.db.loadStore { context, error in
            guard context != nil else {
                if let error = error {
                    Pixel.fire(.debug(event: .syncMetadataCouldNotLoadDatabase, error: error))
                } else {
                    Pixel.fire(.debug(event: .syncMetadataCouldNotLoadDatabase))
                }

                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not create Sync Metadata database stack: \(error?.localizedDescription ?? "err")")
            }
        }
        syncMetadata = LocalSyncMetadataStore(database: syncMetadataDatabase.db)
        isSyncMetadaDatabaseLoaded = true
    }

    private var isSyncMetadaDatabaseLoaded: Bool = false
    private var syncMetadata: SyncMetadataStore?

    private let syncMetadataDatabase: SyncMetadataDatabase = SyncMetadataDatabase()
    private let bookmarksDatabase: CoreDataDatabase
    private let secureVaultFactory: AutofillVaultFactory
}
