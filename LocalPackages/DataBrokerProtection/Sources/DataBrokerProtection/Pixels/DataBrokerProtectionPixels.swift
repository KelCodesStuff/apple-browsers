//
//  DataBrokerProtectionPixels.swift
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
import PixelKit

enum ErrorCategory: Equatable {
    case networkError
    case validationError
    case clientError(httpCode: Int)
    case serverError(httpCode: Int)
    case unclassified

    var toString: String {
        switch self {
        case .networkError: return "network-error"
        case .validationError: return "validation-error"
        case .unclassified: return "unclassified"
        case .clientError(let httpCode): return "client-error-\(httpCode)"
        case .serverError(let httpCode): return "server-error-\(httpCode)"
        }
    }
}

public enum DataBrokerProtectionPixels {
    struct Consts {
        static let dataBrokerParamKey = "data_broker"
        static let appVersionParamKey = "app_version"
        static let attemptIdParamKey = "attempt_id"
        static let durationParamKey = "duration"
        static let bundleIDParamKey = "bundle_id"
        static let stageKey = "stage"
        static let matchesFoundKey = "num_found"
        static let triesKey = "tries"
        static let errorCategoryKey = "error_category"
        static let errorDetailsKey = "error_details"
    }

    case error(error: DataBrokerProtectionError, dataBroker: String)
    case parentChildMatches(parent: String, child: String, value: Int)

    // Stage Pixels
    case optOutStart(dataBroker: String, attemptId: UUID)
    case optOutEmailGenerate(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaParse(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaSend(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaSolve(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutSubmit(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutEmailReceive(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutEmailConfirm(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutValidate(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutFinish(dataBroker: String, attemptId: UUID, duration: Double)

    // Process Pixels
    case optOutSubmitSuccess(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutSuccess(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutFailure(dataBroker: String, attemptId: UUID, duration: Double, stage: String)

    // Backgrond Agent events
    case backgroundAgentStarted
    case backgroundAgentStartedStoppingDueToAnotherInstanceRunning
    case backgroundAgentRunOperationsAndStartSchedulerIfPossible
    case backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile
    // There's currently no point firing this because the scheduler never calls the completion with an error
    // case backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackError(error: Error)
    case backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler

    // IPC server events
    case ipcServerRegister
    case ipcServerStartScheduler
    case ipcServerStopScheduler
    case ipcServerOptOutAllBrokers
    case ipcServerOptOutAllBrokersCompletion(error: Error?)
    case ipcServerScanAllBrokers
    case ipcServerScanAllBrokersCompletion(error: Error?)
    case ipcServerRunQueuedOperations
    case ipcServerRunQueuedOperationsCompletion(error: Error?)
    case ipcServerRunAllOperations

    // Login Item events
    case enableLoginItem
    case restartLoginItem
    case disableLoginItem
    case resetLoginItem

    // DataBrokerProtection User Notifications
    case dataBrokerProtectionNotificationSentFirstScanComplete
    case dataBrokerProtectionNotificationOpenedFirstScanComplete
    case dataBrokerProtectionNotificationSentFirstRemoval
    case dataBrokerProtectionNotificationOpenedFirstRemoval
    case dataBrokerProtectionNotificationScheduled2WeeksCheckIn
    case dataBrokerProtectionNotificationOpened2WeeksCheckIn
    case dataBrokerProtectionNotificationSentAllRecordsRemoved
    case dataBrokerProtectionNotificationOpenedAllRecordsRemoved

    // Scan/Search pixels
    case scanSuccess(dataBroker: String, matchesFound: Int, duration: Double, tries: Int)
    case scanFailed(dataBroker: String, duration: Double, tries: Int)
    case scanError(dataBroker: String, duration: Double, category: String, details: String)

    // KPIs - engagement
    case dailyActiveUser
    case weeklyActiveUser
    case monthlyActiveUser
}

extension DataBrokerProtectionPixels: PixelKitEvent {
    public var name: String {
        switch self {
        case .parentChildMatches: return "m_mac_dbp_macos_parent-child-broker-matches"
            // SLO and SLI Pixels: https://app.asana.com/0/1203581873609357/1205337273100857/f
            // Stage Pixels
        case .optOutStart: return "m_mac_dbp_macos_optout_stage_start"
        case .optOutEmailGenerate: return "m_mac_dbp_macos_optout_stage_email-generate"
        case .optOutCaptchaParse: return "m_mac_dbp_macos_optout_stage_captcha-parse"
        case .optOutCaptchaSend: return "m_mac_dbp_macos_optout_stage_captcha-send"
        case .optOutCaptchaSolve: return "m_mac_dbp_macos_optout_stage_captcha-solve"
        case .optOutSubmit: return "m_mac_dbp_macos_optout_stage_submit"
        case .optOutEmailReceive: return "m_mac_dbp_macos_optout_stage_email-receive"
        case .optOutEmailConfirm: return "m_mac_dbp_macos_optout_stage_email-confirm"
        case .optOutValidate: return "m_mac_dbp_macos_optout_stage_validate"
        case .optOutFinish: return "m_mac_dbp_macos_optout_stage_finish"

            // Process Pixels
        case .optOutSubmitSuccess: return "m_mac_dbp_macos_optout_process_submit-success"
        case .optOutSuccess: return "m_mac_dbp_macos_optout_process_success"
        case .optOutFailure: return "m_mac_dbp_macos_optout_process_failure"

            // Scan/Search pixels: https://app.asana.com/0/1203581873609357/1205337273100855/f
        case .scanSuccess: return "m_mac_dbp_macos_search_stage_main_status_success"
        case .scanFailed: return "m_mac_dbp_macos_search_stage_main_status_failure"
        case .scanError: return "m_mac_dbp_macos_search_stage_main_status_error"

            // Debug Pixels
        case .error: return "m_mac_data_broker_error"

        case .backgroundAgentStarted: return "m_mac_dbp_background-agent_started"
        case .backgroundAgentStartedStoppingDueToAnotherInstanceRunning: return "m_mac_dbp_background-agent_started_stopping-due-to-another-instance-running"

        case .backgroundAgentRunOperationsAndStartSchedulerIfPossible: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible"
        case .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible_no-saved-profile"
        case .backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible_callback_start-scheduler"

        case .ipcServerRegister: return "m_mac_dbp_ipc-server_register"
        case .ipcServerStartScheduler: return "m_mac_dbp_ipc-server_start-scheduler"
        case .ipcServerStopScheduler: return "m_mac_dbp_ipc-server_stop-scheduler"
        case .ipcServerOptOutAllBrokers: return "m_mac_dbp_ipc-server_opt-out-all-brokers"
        case .ipcServerOptOutAllBrokersCompletion: return "m_mac_dbp_ipc-server_opt-out-all-brokers_completion"
        case .ipcServerScanAllBrokers: return "m_mac_dbp_ipc-server_scan-all-brokers"
        case .ipcServerScanAllBrokersCompletion: return "m_mac_dbp_ipc-server_scan-all-brokers_completion"
        case .ipcServerRunQueuedOperations: return "m_mac_dbp_ipc-server_run-queued-operations"
        case .ipcServerRunQueuedOperationsCompletion: return "m_mac_dbp_ipc-server_run-queued-operations_completion"
        case .ipcServerRunAllOperations: return "m_mac_dbp_ipc-server_run-all-operations"

        case .enableLoginItem: return "m_mac_dbp_login-item_enable"
        case .restartLoginItem: return "m_mac_dbp_login-item_restart"
        case .disableLoginItem: return "m_mac_dbp_login-item_disable"
        case .resetLoginItem: return "m_mac_dbp_login-item_reset"

            // User Notifications
        case .dataBrokerProtectionNotificationSentFirstScanComplete:
            return "m_mac_dbp_notification_sent_first_scan_complete"
        case .dataBrokerProtectionNotificationOpenedFirstScanComplete:
            return "m_mac_dbp_notification_opened_first_scan_complete"
        case .dataBrokerProtectionNotificationSentFirstRemoval:
            return "m_mac_dbp_notification_sent_first_removal"
        case .dataBrokerProtectionNotificationOpenedFirstRemoval:
            return "m_mac_dbp_notification_opened_first_removal"
        case .dataBrokerProtectionNotificationScheduled2WeeksCheckIn:
            return "m_mac_dbp_notification_scheduled_2_weeks_check_in"
        case .dataBrokerProtectionNotificationOpened2WeeksCheckIn:
            return "m_mac_dbp_notification_opened_2_weeks_check_in"
        case .dataBrokerProtectionNotificationSentAllRecordsRemoved:
            return "m_mac_dbp_notification_sent_all_records_removed"
        case .dataBrokerProtectionNotificationOpenedAllRecordsRemoved:
            return "m_mac_dbp_notification_opened_all_records_removed"

            // KPIs - engagement
        case .dailyActiveUser: return "m_mac_dbp_engagement_dau"
        case .weeklyActiveUser: return "m_mac_dbp_engagement_wau"
        case .monthlyActiveUser: return "m_mac_dbp_engagement_mau"
        }
    }

    public var params: [String: String]? {
        parameters
    }

    public var parameters: [String: String]? {
        switch self {
        case .error(let error, let dataBroker):
            if case let .actionFailed(actionID, message) = error {
                return ["dataBroker": dataBroker,
                        "name": error.name,
                        "actionID": actionID,
                        "message": message]
            } else {
                return ["dataBroker": dataBroker, "name": error.name]
            }
        case .parentChildMatches(let parent, let child, let value):
            return ["parent": parent, "child": child, "value": String(value)]
        case .optOutStart(let dataBroker, let attemptId):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString]
        case .optOutEmailGenerate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaParse(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSend(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSolve(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmit(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailReceive(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailConfirm(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutValidate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFinish(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmitSuccess(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSuccess(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFailure(let dataBroker, let attemptId, let duration, let stage):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.stageKey: stage]
        case .backgroundAgentStarted,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler,
                .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                .enableLoginItem,
                .restartLoginItem,
                .disableLoginItem,
                .resetLoginItem,
                .dataBrokerProtectionNotificationSentFirstScanComplete,
                .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                .dataBrokerProtectionNotificationSentFirstRemoval,
                .dataBrokerProtectionNotificationOpenedFirstRemoval,
                .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                .dailyActiveUser,
                .weeklyActiveUser,
                .monthlyActiveUser:
            return [:]
        case .ipcServerRegister,
                .ipcServerStartScheduler,
                .ipcServerStopScheduler,
                .ipcServerOptOutAllBrokers,
                .ipcServerOptOutAllBrokersCompletion,
                .ipcServerScanAllBrokers,
                .ipcServerScanAllBrokersCompletion,
                .ipcServerRunQueuedOperations,
                .ipcServerRunQueuedOperationsCompletion,
                .ipcServerRunAllOperations:
            return [Consts.bundleIDParamKey: Bundle.main.bundleIdentifier ?? "nil"]
        case .scanSuccess(let dataBroker, let matchesFound, let duration, let tries):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.matchesFoundKey: String(matchesFound), Consts.durationParamKey: String(duration), Consts.triesKey: String(tries)]
        case .scanFailed(let dataBroker, let duration, let tries):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.durationParamKey: String(duration), Consts.triesKey: String(tries)]
        case .scanError(let dataBroker, let duration, let category, let details):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.durationParamKey: String(duration), Consts.errorCategoryKey: category, Consts.errorDetailsKey: details]
        }
    }
}

public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    // swiftlint:disable:next function_body_length
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .ipcServerOptOutAllBrokersCompletion(error: let error),
                    .ipcServerScanAllBrokersCompletion(error: let error),
                    .ipcServerRunQueuedOperationsCompletion(error: let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .parentChildMatches,
                    .optOutStart,
                    .optOutEmailGenerate,
                    .optOutCaptchaParse,
                    .optOutCaptchaSend,
                    .optOutCaptchaSolve,
                    .optOutSubmit,
                    .optOutEmailReceive,
                    .optOutEmailConfirm,
                    .optOutValidate,
                    .optOutFinish,
                    .optOutSubmitSuccess,
                    .optOutSuccess,
                    .optOutFailure,
                    .backgroundAgentStarted,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .ipcServerRegister,
                    .ipcServerStartScheduler,
                    .ipcServerStopScheduler,
                    .ipcServerOptOutAllBrokers,
                    .ipcServerScanAllBrokers,
                    .ipcServerRunQueuedOperations,
                    .ipcServerRunAllOperations,
                    .enableLoginItem,
                    .restartLoginItem,
                    .disableLoginItem,
                    .resetLoginItem,
                    .scanSuccess,
                    .scanFailed,
                    .scanError,
                    .dataBrokerProtectionNotificationSentFirstScanComplete,
                    .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                    .dataBrokerProtectionNotificationSentFirstRemoval,
                    .dataBrokerProtectionNotificationOpenedFirstRemoval,
                    .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                    .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                    .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                    .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                    .dailyActiveUser,
                    .weeklyActiveUser,
                    .monthlyActiveUser:

                PixelKit.fire(event)
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
