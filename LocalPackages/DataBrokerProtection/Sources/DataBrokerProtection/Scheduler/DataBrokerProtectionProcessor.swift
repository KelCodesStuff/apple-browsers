//
//  DataBrokerProtectionProcessor.swift
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

import Foundation
import Common
import BrowserServicesKit

protocol OperationRunnerProvider {
    func getOperationRunner() -> WebOperationRunner
}

final class DataBrokerProtectionProcessor {
    private let database: DataBrokerProtectionRepository
    private let config: SchedulerConfig
    private let operationRunnerProvider: OperationRunnerProvider
    private let notificationCenter: NotificationCenter
    private let operationQueue: OperationQueue
    private var pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private let engagementPixels: DataBrokerProtectionEngagementPixels

    init(database: DataBrokerProtectionRepository,
         config: SchedulerConfig,
         operationRunnerProvider: OperationRunnerProvider,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         userNotificationService: DataBrokerProtectionUserNotificationService) {

        self.database = database
        self.config = config
        self.operationRunnerProvider = operationRunnerProvider
        self.notificationCenter = notificationCenter
        self.operationQueue = OperationQueue()
        self.pixelHandler = pixelHandler
        self.operationQueue.maxConcurrentOperationCount = config.concurrentOperationsDifferentBrokers
        self.userNotificationService = userNotificationService
        self.engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
    }

    // MARK: - Public functions
    func runAllScanOperations(showWebView: Bool = false, completion: (() -> Void)? = nil) {
        operationQueue.cancelAllOperations()
        runOperations(operationType: .scan,
                      priorityDate: nil,
                      showWebView: showWebView) {
            os_log("Scans done", log: .dataBrokerProtection)
            completion?()
            self.calculateMisMatches()
        }
    }

    private func calculateMisMatches() {
        let mismatchUseCase = MismatchCalculatorUseCase(database: database, pixelHandler: pixelHandler)
        mismatchUseCase.calculateMismatches()
    }

    func runAllOptOutOperations(showWebView: Bool = false, completion: (() -> Void)? = nil) {
        operationQueue.cancelAllOperations()
        runOperations(operationType: .optOut,
                      priorityDate: nil,
                      showWebView: showWebView) {
            os_log("Optouts done", log: .dataBrokerProtection)
            completion?()
        }
    }

    func runQueuedOperations(showWebView: Bool = false, completion: (() -> Void)? = nil ) {
        runOperations(operationType: .all,
                      priorityDate: Date(),
                      showWebView: showWebView) {
            os_log("Queued operations done", log: .dataBrokerProtection)
            completion?()
        }
    }

    func runAllOperations(showWebView: Bool = false, completion: (() -> Void)? = nil ) {
        runOperations(operationType: .all,
                      priorityDate: nil,
                      showWebView: showWebView) {
            os_log("Queued operations done", log: .dataBrokerProtection)
            completion?()
        }
    }

    func stopAllOperations() {
        operationQueue.cancelAllOperations()
    }

    // MARK: - Private functions
    private func runOperations(operationType: DataBrokerOperationsCollection.OperationType,
                               priorityDate: Date?,
                               showWebView: Bool,
                               completion: @escaping () -> Void) {

        // Before running new operations we check if there is any updates to the broker files.
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(errorReporter: nil) {
            let brokerUpdater = DataBrokerProtectionBrokerUpdater(vault: vault)
            brokerUpdater.checkForUpdatesInBrokerJSONFiles()
        }

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()

        let brokersProfileData = database.fetchAllBrokerProfileQueryData()
        let dataBrokerOperationCollections = createDataBrokerOperationCollections(from: brokersProfileData,
                                                                                  operationType: operationType,
                                                                                  priorityDate: priorityDate,
                                                                                  showWebView: showWebView)

        for collection in dataBrokerOperationCollections {
            operationQueue.addOperation(collection)
        }

        operationQueue.addBarrierBlock {
            completion()
        }
    }

    private func createDataBrokerOperationCollections(from brokerProfileQueriesData: [BrokerProfileQueryData],
                                                      operationType: DataBrokerOperationsCollection.OperationType,
                                                      priorityDate: Date?,
                                                      showWebView: Bool) -> [DataBrokerOperationsCollection] {

        var collections: [DataBrokerOperationsCollection] = []
        var visitedDataBrokerIDs: Set<Int64> = []

        for queryData in brokerProfileQueriesData {
            guard let dataBrokerID = queryData.dataBroker.id else { continue }

            if !visitedDataBrokerIDs.contains(dataBrokerID) {
                let collection = DataBrokerOperationsCollection(dataBrokerID: dataBrokerID,
                                                                database: database,
                                                                operationType: operationType,
                                                                intervalBetweenOperations: config.intervalBetweenSameBrokerOperations,
                                                                priorityDate: priorityDate,
                                                                notificationCenter: notificationCenter,
                                                                runner: operationRunnerProvider.getOperationRunner(),
                                                                pixelHandler: pixelHandler,
                                                                userNotificationService: userNotificationService,
                                                                showWebView: showWebView)
                collections.append(collection)

                visitedDataBrokerIDs.insert(dataBrokerID)
            }
        }

        return collections
    }

    deinit {
        os_log("Deinit DataBrokerProtectionProcessor", log: .dataBrokerProtection)
    }
}
