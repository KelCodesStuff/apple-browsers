//
//  DataBrokerProfileQueryOperationManagerTests.swift
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

// swiftlint:disable type_body_length

import XCTest
import BrowserServicesKit
@testable import DataBrokerProtection

final class DataBrokerProfileQueryOperationManagerTests: XCTestCase {
    let sut = DataBrokerProfileQueryOperationManager()
    let mockWebOperationRunner = MockWebOperationRunner()
    let mockDatabase = MockDatabase()
    let mockUserNotification = MockUserNotification()

    override func tearDown() {
        mockWebOperationRunner.clear()
        mockUserNotification.reset()
    }

    // MARK: - Notification tests

    func testWhenOnlyOneProfileIsFoundAndRemoved_thenAllInfoRemovedNotificationIsSent() async {
        do {
            let config = DataBrokerScheduleConfig(retryError: 1000, confirmOptOutScan: 1000, maintenanceScan: 1000)

            let brokerId: Int64 = 1
            let profileQueryId: Int64 = 1
            let extractedProfileId: Int64 = 1
            let currentPreferredRunDate = Date()

            let mockDataBroker = DataBroker(name: "databroker", url: "databroker.com", steps: [Step](), version: "1.0", schedulingConfig: config)
            let mockProfileQuery = ProfileQuery(id: profileQueryId, firstName: "a", lastName: "b", city: "c", state: "d", birthYear: 1222)

            let historyEvents = [HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)]
            let mockScanOperation = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, preferredRunDate: currentPreferredRunDate, historyEvents: historyEvents)

            let extractedProfileSaved = ExtractedProfile(id: 1, name: "Some name", profileUrl: "abc")

            let optOutData = [OptOutOperationData.mock(with: extractedProfileSaved)]

            let mockBrokerProfileQuery = BrokerProfileQueryData(dataBroker: mockDataBroker,
                                                                profileQuery: mockProfileQuery,
                                                                scanOperationData: mockScanOperation,
            optOutOperationsData: optOutData)
            mockDatabase.brokerProfileQueryDataToReturn = [mockBrokerProfileQuery]

            mockWebOperationRunner.scanResults = []
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: extractedProfileSaved)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: mockUserNotification,
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockUserNotification.allInfoRemovedWasSent)
            XCTAssertFalse(mockUserNotification.firstRemovedNotificationWasSent)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenManyProfilesAreFoundAndOnlyOneRemoved_thenFirstRemovedNotificationIsSent() async {
        do {

            let config = DataBrokerScheduleConfig(retryError: 1000, confirmOptOutScan: 1000, maintenanceScan: 1000)

            let brokerId: Int64 = 1
            let profileQueryId: Int64 = 1
            let extractedProfileId: Int64 = 1
            let currentPreferredRunDate = Date()

            let mockDataBroker = DataBroker(name: "databroker", url: "databroker.com", steps: [Step](), version: "1.0", schedulingConfig: config)
            let mockProfileQuery = ProfileQuery(id: profileQueryId, firstName: "a", lastName: "b", city: "c", state: "d", birthYear: 1222)

            let historyEvents = [HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)]
            let mockScanOperation = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, preferredRunDate: currentPreferredRunDate, historyEvents: historyEvents)

            let extractedProfileSaved1 = ExtractedProfile(id: 1, name: "Some name", profileUrl: "abc", identifier: "abc")
            let extractedProfileSaved2 = ExtractedProfile(id: 1, name: "Some name", profileUrl: "zxz", identifier: "zxz")

            let optOutData = [OptOutOperationData.mock(with: extractedProfileSaved1),
                              OptOutOperationData.mock(with: extractedProfileSaved2)]

            let mockBrokerProfileQuery = BrokerProfileQueryData(dataBroker: mockDataBroker,
                                                                profileQuery: mockProfileQuery,
                                                                scanOperationData: mockScanOperation,
            optOutOperationsData: optOutData)
            mockDatabase.brokerProfileQueryDataToReturn = [mockBrokerProfileQuery]

            mockWebOperationRunner.scanResults = [extractedProfileSaved1]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: extractedProfileSaved1),
                                           OptOutOperationData.mock(with: extractedProfileSaved2)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: mockUserNotification,
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockUserNotification.allInfoRemovedWasSent)
            XCTAssertTrue(mockUserNotification.firstRemovedNotificationWasSent)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenNoProfilesAreRemoved_thenNoNotificationsAreSent() async {
        do {

            let config = DataBrokerScheduleConfig(retryError: 1000, confirmOptOutScan: 1000, maintenanceScan: 1000)

            let brokerId: Int64 = 1
            let profileQueryId: Int64 = 1
            let extractedProfileId: Int64 = 1
            let currentPreferredRunDate = Date()

            let mockDataBroker = DataBroker(name: "databroker", url: "databroker.com", steps: [Step](), version: "1.0", schedulingConfig: config)
            let mockProfileQuery = ProfileQuery(id: profileQueryId, firstName: "a", lastName: "b", city: "c", state: "d", birthYear: 1222)

            let historyEvents = [HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)]
            let mockScanOperation = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, preferredRunDate: currentPreferredRunDate, historyEvents: historyEvents)

            let extractedProfileSaved1 = ExtractedProfile(id: 1, name: "Some name", profileUrl: "abc")
            let extractedProfileSaved2 = ExtractedProfile(id: 1, name: "Some name", profileUrl: "zxz")

            let optOutData = [OptOutOperationData.mock(with: extractedProfileSaved1),
                              OptOutOperationData.mock(with: extractedProfileSaved2)]

            let mockBrokerProfileQuery = BrokerProfileQueryData(dataBroker: mockDataBroker,
                                                                profileQuery: mockProfileQuery,
                                                                scanOperationData: mockScanOperation,
            optOutOperationsData: optOutData)
            mockDatabase.brokerProfileQueryDataToReturn = [mockBrokerProfileQuery]

            mockWebOperationRunner.scanResults = [extractedProfileSaved1, extractedProfileSaved2]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: extractedProfileSaved1),
                                           OptOutOperationData.mock(with: extractedProfileSaved2)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: mockUserNotification,
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockUserNotification.allInfoRemovedWasSent)
            XCTAssertFalse(mockUserNotification.firstRemovedNotificationWasSent)
        } catch {
            XCTFail("Should not throw")
        }
    }

    // MARK: - Run scan operation tests

    func testWhenProfileQueryIdIsNil_thenRunScanOperationThrows() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mockWithoutId,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasScanCalled)
        }
    }

    func testWhenBrokerIdIsNil_thenRunScanOperationThrows() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithoutId,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id for broker")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
        }
    }

    func testWhenScanStarts_thenScanStartedEventIsAddedToTheDatabase() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertEqual(mockDatabase.eventsAdded.first?.type, .scanStarted)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScanDoesNotFoundProfiles_thenNoMatchFoundEventIsAddedToTheDatabase() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .noMatchFound }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScannedProfileIsAlreadyInTheDatabase_noOptOutOperationIsCreated() async {
        do {
            mockDatabase.extractedProfilesFromBroker = [.mockWithoutRemovedDate]
            mockWebOperationRunner.scanResults = [.mockWithoutRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertNil(mockDatabase.extractedProfileRemovedDate)
            XCTAssertFalse(mockDatabase.wasSaveOptOutOperationCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScannedProfileIsAlreadyInTheDatabaseAndWasRemoved_thenTheRemovedDateIsSetBackToNil() async {
        do {
            mockDatabase.extractedProfilesFromBroker = [.mockWithRemovedDate]
            mockWebOperationRunner.scanResults = [.mockWithRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertNil(mockDatabase.extractedProfileRemovedDate)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScannedProfileIsAlreadyInTheDatabaseAndWasNotFoundInBroker_thenTheRemovedDateIsSet() async {
        do {
            mockWebOperationRunner.scanResults = []
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertNotNil(mockDatabase.extractedProfileRemovedDate)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenNewExtractedProfileIsNotInDatabase_thenIsAddedToTheDatabaseAndOptOutOperationIsCreated() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.wasSaveOptOutOperationCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenRemovedProfileIsFound_thenOptOutConfirmedIsAddedRemoveDateIsUpdatedAndPreferredRunDateIsSetToNil() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutConfirmed }))
            XCTAssertTrue(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertNotNil(mockDatabase.extractedProfileRemovedDate)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenNoRemovedProfilesAreFound_thenNoOtherEventIsAdded() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutConfirmed }))
            XCTAssertFalse(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertNil(mockDatabase.extractedProfileRemovedDate)
            XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenErrorIsCaught_thenEventIsAddedToTheDatabase() async {
        do {
            mockWebOperationRunner.shouldScanThrow = true
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Should throw!")
        } catch {
            XCTAssertTrue(mockDatabase.wasAddHistoryEventCalled)
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .error(error: .unknown("Test error")) }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .matchesFound(count: 1) }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .noMatchFound }))
            XCTAssertFalse(mockDatabase.wasSaveOptOutOperationCalled)
        }
    }

    // MARK: - Run opt-out operation tests

    func testWhenNoBrokerIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithoutId,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenNoProfileQueryIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mockWithoutId,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenNoExtractedProfileIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutId,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutId)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenExtractedProfileHasRemovedDate_thenNothingHappens() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockDatabase.wasDatabaseCalled)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenBrokerHasParentOptOut_thenNothingHappens() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithParentOptOut,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertFalse(mockDatabase.wasDatabaseCalled)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testOptOutStartedEventIsAdded_whenExtractedProfileOptOutStarts() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutStarted }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testOptOutRequestedEventIsAdded_whenExtractedProfileOptOutFinishesWithoutError() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutRequested }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testErrorEventIsAdded_whenWebRunnerFails() async {
        do {
            mockWebOperationRunner.shouldOptOutThrow = true
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("Should throw!")
        } catch {
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutStarted }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutRequested }))
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .error(error: DataBrokerProtectionError.unknown("Test error")) }))
        }
    }

    func testCorrectDataBrokerTypeIsSent_whenOptOutIsDoneInChildSite() async {
        do {
            mockDatabase.attemptInformation = .mock
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithParentOptOut,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )

            if let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last {
                switch lastPixelFired {
                case .optOutSuccess(_, _, _, let type):
                    XCTAssertEqual(type, .child)
                default: XCTFail("We should be firing the opt-out submit pixel last")
                }
            } else {
                XCTFail("We should be firing the opt-out submit pixel")
            }
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testCorrectDataBrokerTypeIsSent_whenOptOutIsDoneInParentSite() async {
        do {
            mockDatabase.attemptInformation = .mock
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )

            if let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last {
                switch lastPixelFired {
                case .optOutSuccess(_, _, _, let type):
                    XCTAssertEqual(type, .parent)
                default: XCTFail("We should be firing the opt-out submit pixel last")
                }
            } else {
                XCTFail("We should be firing the opt-out submit pixel")
            }
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testCorrectNumberOfTriesIsFired_whenOptOutSucceeds() async {
        do {
            mockDatabase.historyEvents = [
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
                .init(brokerId: 1, profileQueryId: 1, type: .error(error: .cancelled)),
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
                .init(brokerId: 1, profileQueryId: 1, type: .error(error: .cancelled)),
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            ]
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            if let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last {
                switch lastPixelFired {
                case .optOutSubmitSuccess(_, _, _, let tries, _):
                    XCTAssertEqual(tries, 3)
                default: XCTFail("We should be firing the opt-out submit-success pixel last")
                }
            } else {
                XCTFail("We should be firing the opt-out submit-success pixel")
            }
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testCorrectNumberOfTriesIsFired_whenOptOutFails() async {
        do {
            mockWebOperationRunner.shouldOptOutThrow = true
            mockDatabase.historyEvents = [
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
                .init(brokerId: 1, profileQueryId: 1, type: .error(error: .cancelled)),
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
                .init(brokerId: 1, profileQueryId: 1, type: .error(error: .cancelled)),
                .init(brokerId: 1, profileQueryId: 1, type: .optOutStarted),
            ]
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default,
                pixelHandler: MockDataBrokerProtectionPixelsHandler(),
                userNotificationService: MockUserNotification(),
                shouldRunNextStep: { true }
            )
            XCTFail("The code above should throw")
        } catch {
            if let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last {
                switch lastPixelFired {
                case .optOutFailure(_, _, _, _, let tries, _):
                    XCTAssertEqual(tries, 3)
                default: XCTFail("We should be firing the opt-out submit-success pixel last")
                }
            } else {
                XCTFail("We should be firing the opt-out submit-success pixel")
            }
        }
    }

    // MARK: - Update operation dates tests

    func testWhenUpdatingDatesOnOptOutAndLastEventIsError_thenWeSetPreferredRunDateWithRetryErrorDate() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown("Test error")))
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 0, maintenanceScan: 0)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnOptOut, date2: Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)))
    }

    func testWhenUpdatingDatesOnScanAndLastEventIsError_thenWeSetPreferredRunDateWithRetryErrorDate() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: nil, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown("Test error")))
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 0, maintenanceScan: 0)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: nil, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutRequested_thenWeSetScanPreferredRunDateWithConfirmOptOutDate() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 1, maintenanceScan: 0)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutRequested_thenWeSetOptOutPreferredRunDateToNil() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 1, maintenanceScan: 0)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }

    func testWhenUpdatingDatesAndLastEventIsMatchesFound_thenWeSetScanPreferredDateToMaintanence() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .matchesFound(count: 0))
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutStarted_thenNothingHappens() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutStarted)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnScan)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }

    func testWhenUpdatingDatesAndLastEventIsScanStarted_thenNothingHappens() throws {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .scanStarted)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnScan)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }

    func testUpdatingScanDateFromOptOut_thenScanRespectMostRecentDate() throws {
        let config = DataBrokerScheduleConfig(retryError: 1000, confirmOptOutScan: 1000, maintenanceScan: 1000)

        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        let currentPreferredRunDate = Date()

        let mockDataBroker = DataBroker(name: "databroker", url: "databroker.com", steps: [Step](), version: "1.0", schedulingConfig: config)
        let mockProfileQuery = ProfileQuery(id: profileQueryId, firstName: "a", lastName: "b", city: "c", state: "d", birthYear: 1222)

        let historyEvents = [HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)]
        let mockScanOperation = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, preferredRunDate: currentPreferredRunDate, historyEvents: historyEvents)

        let mockBrokerProfileQuery = BrokerProfileQueryData(dataBroker: mockDataBroker, profileQuery: mockProfileQuery, scanOperationData: mockScanOperation)
        mockDatabase.brokerProfileQueryDataToReturn = [mockBrokerProfileQuery]

        try sut.updateOperationDataDates(origin: .optOut, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: config, database: mockDatabase)

        // If the date is not going to be set, we don't call the database function
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
    }

    func testUpdatingScanDateFromScan_thenScanDoesNotRespectMostRecentDate() throws {
        let config = DataBrokerScheduleConfig(retryError: 1000, confirmOptOutScan: 1000, maintenanceScan: 1000)

        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        let currentPreferredRunDate = Date()
        let expectedPreferredRunDate = Date().addingTimeInterval(config.confirmOptOutScan.hoursToSeconds)

        let mockDataBroker = DataBroker(name: "databroker", url: "databroker.com", steps: [Step](), version: "1.0", schedulingConfig: config)
        let mockProfileQuery = ProfileQuery(id: profileQueryId, firstName: "a", lastName: "b", city: "c", state: "d", birthYear: 1222)

        let historyEvents = [HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)]
        let mockScanOperation = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, preferredRunDate: currentPreferredRunDate, historyEvents: historyEvents)

        let mockBrokerProfileQuery = BrokerProfileQueryData(dataBroker: mockDataBroker, profileQuery: mockProfileQuery, scanOperationData: mockScanOperation)
        mockDatabase.brokerProfileQueryDataToReturn = [mockBrokerProfileQuery]

        try sut.updateOperationDataDates(origin: .scan, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: config, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: expectedPreferredRunDate), "\(String(describing: mockDatabase.lastPreferredRunDateOnScan)) is not equal to \(expectedPreferredRunDate)")
    }
}

final class MockWebOperationRunner: WebOperationRunner {

    var shouldScanThrow = false
    var shouldOptOutThrow = false
    var scanResults = [ExtractedProfile]()
    var wasScanCalled = false
    var wasOptOutCalled = false

    func scan(_ profileQuery: BrokerProfileQueryData, stageCalculator: StageDurationCalculator, showWebView: Bool, shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile] {
        wasScanCalled = true

        if shouldScanThrow {
            throw DataBrokerProtectionError.unknown("Test error")
        } else {
            return scanResults
        }
    }

    func optOut(profileQuery: BrokerProfileQueryData, extractedProfile: ExtractedProfile, stageCalculator: StageDurationCalculator, showWebView: Bool, shouldRunNextStep: @escaping () -> Bool) async throws {
        wasOptOutCalled = true

        if shouldOptOutThrow {
            throw DataBrokerProtectionError.unknown("Test error")
        }
    }

    func clear() {
        shouldScanThrow = false
        shouldOptOutThrow = false
        scanResults.removeAll()
        wasScanCalled = false
        wasOptOutCalled = false
    }
}

extension ScanOperationData {

    static var mock: ScanOperationData {
        .init(
            brokerId: 1,
            profileQueryId: 1,
            historyEvents: [HistoryEvent]()
        )
    }
}

extension OptOutOperationData {

    static func mock(with extractedProfile: ExtractedProfile) -> OptOutOperationData {
        .init(brokerId: 1, profileQueryId: 1, historyEvents: [HistoryEvent](), extractedProfile: extractedProfile)
    }
}

extension DataBroker {

    static var mock: DataBroker {
        DataBroker(
            id: 1,
            name: "Test broker",
            url: "testbroker.com",
            steps: [
                Step(type: .scan, actions: [Action]()),
                Step(type: .optOut, actions: [Action]())
            ],
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            )
        )
    }

    static var mockWithParentOptOut: DataBroker {
        DataBroker(
            id: 1,
            name: "Test broker",
            url: "testbroker.com",
            steps: [
                Step(type: .scan, actions: [Action]()),
                Step(type: .optOut, actions: [Action](), optOutType: .parentSiteOptOut)
            ],
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            ),
            parent: "some"
        )
    }

    static var mockWithoutId: DataBroker {
        DataBroker(
            name: "Test broker",
            url: "testbroker.com",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            )
        )
    }
}

extension ProfileQuery {

    static var mock: ProfileQuery {
        .init(id: 1, firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }

    static var mockWithoutId: ProfileQuery {
        .init(firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }
}

extension ExtractedProfile {

    static var mockWithRemovedDate: ExtractedProfile {
        ExtractedProfile(id: 1, name: "Some name", profileUrl: "someURL", removedDate: Date(), identifier: "someURL")
    }

    static var mockWithoutRemovedDate: ExtractedProfile {
        ExtractedProfile(id: 1, name: "Some name", profileUrl: "someURL", identifier: "someURL")
    }

    static var mockWithoutId: ExtractedProfile {
        ExtractedProfile(name: "Some name", profileUrl: "someOtherURL", identifier: "someOtherURL")
    }

    static func mockWithRemoveDate(_ date: Date) -> ExtractedProfile {
        ExtractedProfile(id: 1, name: "Some name", profileUrl: "someURL", removedDate: date, identifier: "someURL")
    }
}

final class MockUserNotification: DataBrokerProtectionUserNotificationService {

    var requestPermissionWasAsked = false
    var firstScanNotificationWasSent = false
    var firstRemovedNotificationWasSent = false
    var checkInNotificationWasScheduled = false
    var allInfoRemovedWasSent = false

    func requestNotificationPermission() {
        requestPermissionWasAsked = true
    }

    func sendFirstScanCompletedNotification() {
        firstScanNotificationWasSent = true
    }

    func sendFirstRemovedNotificationIfPossible() {
        firstRemovedNotificationWasSent = true
    }

    func sendAllInfoRemovedNotificationIfPossible() {
        allInfoRemovedWasSent = true
    }

    func scheduleCheckInNotificationIfPossible() {
        checkInNotificationWasScheduled = true
    }

    func reset() {
        requestPermissionWasAsked = false
        firstScanNotificationWasSent = false
        firstRemovedNotificationWasSent = false
        checkInNotificationWasScheduled = false
        allInfoRemovedWasSent = false
    }
}

extension AttemptInformation {

    static var mock: AttemptInformation {
        AttemptInformation(extractedProfileId: 1,
                           dataBroker: "broker",
                           attemptId: UUID().uuidString,
                           lastStageDate: Date(),
                           startDate: Date())
    }
}

// swiftlint:enable type_body_length
