//
//  DataBrokerProtectionIOSManager.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Combine
import Common
import BrowserServicesKit
import PixelKit
import os.log
import Subscription
import UserNotifications
import DataBrokerProtectionCore
import WebKit
import BackgroundTasks

public class DefaultOperationEventsHandler: EventMapping<JobEvent> {

    public init() {
        super.init { event, _, _, _ in
            switch event {
            default:
                print("event happened")
            }
        }
    }

    @available(*, unavailable)
    override init(mapping: @escaping EventMapping<JobEvent>.Mapping) {
        fatalError("Use init()")
    }
}

extension DataBrokerProtectionSettings: @retroactive AppRunTypeProviding {

    public var runType: AppVersion.AppRunType {
        return AppVersion.AppRunType.normal
    }
}

public class DataBrokerProtectionIOSManagerProvider {

    private let databaseURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: DatabaseConstants.directoryName, fileName: DatabaseConstants.fileName)

    public static func iOSManager(authenticationManager: DataBrokerProtectionAuthenticationManaging,
                                  privacyConfigurationManager: PrivacyConfigurationManaging,
                                  featureFlagger: RemoteBrokerDeliveryFeatureFlagging,
                                  pixelKit: PixelKit,
                                  quickLinkOpenURLHandler: @escaping (URL) -> Void) -> DataBrokerProtectionIOSManager? {
        let sharedPixelsHandler = DataBrokerProtectionSharedPixelsHandler(pixelKit: pixelKit, platform: .iOS)
        let iOSPixelsHandler = IOSPixelsHandler(pixelKit: pixelKit)

        let dbpSettings = DataBrokerProtectionSettings(defaults: .dbp)

        let eventsHandler = DefaultOperationEventsHandler()

        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false,
                                                  unknownUsernameCategorization: false,
                                                  partialFormSaves: false,
                                                  passwordVariantCategorization: false,
                                                  inputFocusApi: false)
        let contentScopeProperties = ContentScopeProperties(gpcEnabled: false,
                                                            sessionKey: UUID().uuidString,
                                                            messageSecret: UUID().uuidString,
                                                            featureToggles: features)

        let fakeBroker = DataBrokerDebugFlagFakeBroker()
        let databaseURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: DatabaseConstants.directoryName, fileName: DatabaseConstants.fileName)
        let vaultFactory = createDataBrokerProtectionSecureVaultFactory(appGroupName: nil, databaseFileURL: databaseURL)

        let reporter = DataBrokerProtectionSecureVaultErrorReporter(pixelHandler: sharedPixelsHandler)

        let vault: DefaultDataBrokerProtectionSecureVault<DefaultDataBrokerProtectionDatabaseProvider>
        do {
            vault = try vaultFactory.makeVault(reporter: reporter)
        } catch {
            assertionFailure("Failed to make secure storage vault")
            return nil
        }

        let localBrokerService = LocalBrokerJSONService(vault: vault, pixelHandler: sharedPixelsHandler)

        let database = DataBrokerProtectionDatabase(fakeBrokerFlag: fakeBroker, pixelHandler: sharedPixelsHandler, vault: vault, localBrokerService: localBrokerService)

        let operationQueue = OperationQueue()
        let jobProvider = BrokerProfileJobProvider()
        let mismatchCalculator = DefaultMismatchCalculator(database: database,
                                                           pixelHandler: sharedPixelsHandler)

        let queueManager =  BrokerProfileJobQueueManager(jobQueue: operationQueue,
                                                         jobProvider: jobProvider,
                                                         mismatchCalculator: mismatchCalculator,
                                                         pixelHandler: sharedPixelsHandler)

        let backendServicePixels = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: sharedPixelsHandler,
                                                                                   settings: dbpSettings)
        let emailService = EmailService(authenticationManager: authenticationManager,
                                        settings: dbpSettings,
                                        servicePixel: backendServicePixels)
        let captchaService = CaptchaService(authenticationManager: authenticationManager, settings: dbpSettings, servicePixel: backendServicePixels)
        let executionConfig = BrokerJobExecutionConfig()
        let jobDependencies = BrokerProfileJobDependencies(
            database: database,
            contentScopeProperties: contentScopeProperties,
            privacyConfig: privacyConfigurationManager,
            executionConfig: executionConfig,
            notificationCenter: NotificationCenter.default,
            pixelHandler: sharedPixelsHandler,
            eventsHandler: eventsHandler,
            dataBrokerProtectionSettings: dbpSettings,
            emailService: emailService,
            captchaService: captchaService,
            vpnBypassService: nil)

        return DataBrokerProtectionIOSManager(
            queueManager: queueManager,
            jobDependencies: jobDependencies,
            authenticationManager: authenticationManager,
            sharedPixelsHandler: sharedPixelsHandler,
            iOSPixelsHandler: iOSPixelsHandler,
            privacyConfigManager: privacyConfigurationManager,
            database: database,
            quickLinkOpenURLHandler: quickLinkOpenURLHandler
        )
    }
}

public final class DataBrokerProtectionIOSManager {

    public static let backgroundJobIdentifier = "com.duckduckgo.app.dbp.backgroundProcessing"
    public static var shared: DataBrokerProtectionIOSManager?

    public let database: DataBrokerProtectionRepository
    private let queueManager: BrokerProfileJobQueueManager
    private let jobDependencies: BrokerProfileJobDependencies
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let sharedPixelsHandler: EventMapping<DataBrokerProtectionSharedPixels>
    private let iOSPixelsHandler: EventMapping<IOSPixels>
    private let privacyConfigManager: PrivacyConfigurationManaging
    private let quickLinkOpenURLHandler: (URL) -> Void

    init(queueManager: BrokerProfileJobQueueManager,
         jobDependencies: BrokerProfileJobDependencies,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         sharedPixelsHandler: EventMapping<DataBrokerProtectionSharedPixels>,
         iOSPixelsHandler: EventMapping<IOSPixels>,
         privacyConfigManager: PrivacyConfigurationManaging,
         database: DataBrokerProtectionRepository,
         quickLinkOpenURLHandler: @escaping (URL) -> Void
    ) {
        self.queueManager = queueManager
        self.jobDependencies = jobDependencies
        self.authenticationManager = authenticationManager
        self.sharedPixelsHandler = sharedPixelsHandler
        self.iOSPixelsHandler = iOSPixelsHandler
        self.privacyConfigManager = privacyConfigManager
        self.database = database
        self.quickLinkOpenURLHandler = quickLinkOpenURLHandler

        registerBackgroundTaskHandler()
    }

    private func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundJobIdentifier, using: nil) { task in
            self.handleBGProcessingTask(task: task)
        }
    }

    public func scheduleBGProcessingTask() {
        Task {
            guard await validateRunPrerequisites() else {
                Logger.dataBrokerProtection.log("Prerequisites are invalid during scheduling of background task")
                return
            }
            
            let request = BGProcessingTaskRequest(identifier: "com.duckduckgo.app.dbp.backgroundProcessing")
            request.requiresNetworkConnectivity = true
            
#if !targetEnvironment(simulator)
            do {
                try BGTaskScheduler.shared.submit(request)
                Logger.dataBrokerProtection.log("Scheduling background task successful")
            } catch {
                Logger.dataBrokerProtection.log("Scheduling background task failed with error: \(error)")
// This should never ever go to production due to the deviceID and only exists for internal testing as long as PIR isn't public on iOS
                self.iOSPixelsHandler.fire(.backgroundTaskSchedulingFailed(error: error, deviceID: DataBrokerProtectionSettings.deviceIdentifier))
            }
#endif
        }
    }

    func handleBGProcessingTask(task: BGTask) {
        Logger.dataBrokerProtection.log("Background task started")
// This should never ever go to production due to the deviceID and only exists for internal testing as long as PIR isn't public on iOS
        iOSPixelsHandler.fire(.backgroundTaskStarted(deviceID: DataBrokerProtectionSettings.deviceIdentifier))
        let startTime = Date.now

        task.expirationHandler = {
            let timeTaken = Date.now.timeIntervalSince(startTime)
            Logger.dataBrokerProtection.log("Background task expired with time taken: \(timeTaken)")
// This should never ever go to production due to the deviceID and only exists for internal testing as long as PIR isn't public on iOS
            self.iOSPixelsHandler.fire(.backgroundTaskExpired(duration: timeTaken * 1000.0,
                                                              deviceID: DataBrokerProtectionSettings.deviceIdentifier))
            self.scheduleBGProcessingTask()
            task.setTaskCompleted(success: false)
        }

        Task {
            guard await validateRunPrerequisites() else {
                Logger.dataBrokerProtection.log("Prerequisites are invalid during background task")
                task.setTaskCompleted(success: false)
                return
            }
            queueManager.startScheduledAllOperationsIfPermitted(showWebView: false, jobDependencies: jobDependencies, errorHandler: nil) {
                Logger.dataBrokerProtection.log("All operations completed in background task")
                let timeTaken = Date.now.timeIntervalSince(startTime)
                Logger.dataBrokerProtection.log("Background task finshed all operations with time taken: \(timeTaken)")
// This should never ever go to production due to the deviceID and only exists for internal testing as long as PIR isn't public on iOS
                self.iOSPixelsHandler.fire(.backgroundTaskEndedHavingCompletedAllJobs(
                    duration: timeTaken * 1000.0,
                    deviceID: DataBrokerProtectionSettings.deviceIdentifier))

                self.scheduleBGProcessingTask()
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// Used by the iOS PIR debug menu to reset tester data.
    public func deleteAllData() throws {
        try database.deleteProfileData()
    }

    // MARK: - Run Prerequisites

    public var meetsProfileRunPrequisite: Bool {
        get throws {
            return try database.fetchProfile() != nil
        }
    }

    public var meetsAuthenticationRunPrequisite: Bool {
        return authenticationManager.isUserAuthenticated
    }

    public var meetsEntitlementRunPrequisite: Bool {
        get async throws {
            return try await authenticationManager.hasValidEntitlement()
        }
    }

    public func validateRunPrerequisites() async -> Bool {
        do {
            if !(try meetsProfileRunPrequisite) || !meetsAuthenticationRunPrequisite {
                Logger.dataBrokerProtection.log("Prerequisites are invalid")
                return false
            }

            return try await meetsEntitlementRunPrequisite
        } catch {
            Logger.dataBrokerProtection.error("Error validating prerequisites, error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

extension DataBrokerProtectionIOSManager: DataBrokerProtectionViewControllerProvider {
    public func dataBrokerProtectionViewController() -> DataBrokerProtectionViewController {
        return DataBrokerProtectionViewController(dbpUIViewModelDelegate: self,
                                                  privacyConfigManager: self.privacyConfigManager,
                                                  contentScopeProperties: self.jobDependencies.contentScopeProperties,
                                                  webUISettings: DataBrokerProtectionWebUIURLSettings(.dbp),
                                                  openURLHandler: quickLinkOpenURLHandler)
    }
}

extension DataBrokerProtectionIOSManager: DBPUIViewModelDelegate {
    public func isUserAuthenticated() -> Bool {
        authenticationManager.isUserAuthenticated
    }
    
    public func getUserProfile() throws -> DataBrokerProtectionCore.DataBrokerProtectionProfile? {
        try database.fetchProfile()
    }
    
    public func getAllDataBrokers() throws -> [DataBrokerProtectionCore.DataBroker] {
        try database.fetchAllDataBrokers()
    }
    
    public func getAllBrokerProfileQueryData() throws -> [DataBrokerProtectionCore.BrokerProfileQueryData] {
        try database.fetchAllBrokerProfileQueryData()
    }
    
    public func saveProfile(_ profile: DataBrokerProtectionCore.DataBrokerProtectionProfile) async throws {
        try await database.save(profile)
        queueManager.startScheduledAllOperationsIfPermitted(showWebView: false, jobDependencies: jobDependencies, errorHandler: nil) {
        }
    }
    
    public func deleteAllUserProfileData() throws {
        try database.deleteProfileData()
        DataBrokerProtectionSettings(defaults: .dbp).resetBrokerDeliveryData()
    }
    
    public func matchRemovedByUser(with id: Int64) throws {
        try database.matchRemovedByUser(id)
    }

}
