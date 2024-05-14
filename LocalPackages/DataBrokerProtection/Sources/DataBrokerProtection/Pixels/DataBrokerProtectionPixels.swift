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
    case databaseError(domain: String, code: Int)
    case unclassified

    var toString: String {
        switch self {
        case .networkError: return "network-error"
        case .validationError: return "validation-error"
        case .unclassified: return "unclassified"
        case .clientError(let httpCode): return "client-error-\(httpCode)"
        case .serverError(let httpCode): return "server-error-\(httpCode)"
        case .databaseError(let domain, let code): return "database-error-\(domain)-\(code)"
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
        static let pattern = "pattern"
        static let isParent = "is_parent"
        static let actionIDKey = "action_id"
        static let hadNewMatch = "had_new_match"
        static let hadReAppereance = "had_re-appearance"
        static let scanCoverage = "scan_coverage"
        static let removals = "removals"
        static let environmentKey = "environment"
        static let wasOnWaitlist = "was_on_waitlist"
        static let httpCode = "http_code"
        static let backendServiceCallSite = "backend_service_callsite"
        static let isImmediateOperation = "is_manual_scan"
        static let durationInMs = "duration_in_ms"
        static let profileQueries = "profile_queries"
        static let hasError = "has_error"
        static let brokerURL = "broker_url"
    }

    case error(error: DataBrokerProtectionError, dataBroker: String)
    case generalError(error: Error, functionOccurredIn: String)
    case secureVaultInitError(error: Error)
    case secureVaultError(error: Error)
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
    case optOutFillForm(dataBroker: String, attemptId: UUID, duration: Double)

    // Process Pixels
    case optOutSubmitSuccess(dataBroker: String, attemptId: UUID, duration: Double, tries: Int, emailPattern: String?)
    case optOutSuccess(dataBroker: String, attemptId: UUID, duration: Double, brokerType: DataBrokerHierarchy)
    case optOutFailure(dataBroker: String, attemptId: UUID, duration: Double, stage: String, tries: Int, emailPattern: String?, actionID: String?)

    // Backgrond Agent events
    case backgroundAgentStarted
    case backgroundAgentStartedStoppingDueToAnotherInstanceRunning
    case backgroundAgentRunOperationsAndStartSchedulerIfPossible
    case backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile
    // There's currently no point firing this because the scheduler never calls the completion with an error
    // case backgroundAgentRunOperationsAndStartSchedulerIfPossibleStartScheduledOperationsCallbackError(error: Error)
    case backgroundAgentRunOperationsAndStartSchedulerIfPossibleStartScheduledOperationsCallbackStartScheduler

    // IPC server events
    case ipcServerStartSchedulerCalledByApp
    case ipcServerStartSchedulerReceivedByAgent
    case ipcServerStartSchedulerXPCError(error: Error?)

    case ipcServerStopSchedulerCalledByApp
    case ipcServerStopSchedulerReceivedByAgent
    case ipcServerStopSchedulerXPCError(error: Error?)

    case ipcServerScanAllBrokersAttemptedToCallWithoutLoginItemPermissions
    case ipcServerScanAllBrokersAttemptedToCallInWrongDirectory
    case ipcServerScanAllBrokersCalledByApp
    case ipcServerScanAllBrokersReceivedByAgent
    case ipcServerScanAllBrokersXPCError(error: Error?)

    case ipcServerScanAllBrokersCompletedOnAgentWithoutError
    case ipcServerScanAllBrokersCompletedOnAgentWithError(error: Error?)
    case ipcServerScanAllBrokersCompletionCalledOnAppWithoutError
    case ipcServerScanAllBrokersCompletionCalledOnAppWithError(error: Error?)
    case ipcServerScanAllBrokersInterruptedOnAgent
    case ipcServerScanAllBrokersCompletionCalledOnAppAfterInterruption

    case ipcServerOptOutAllBrokers
    case ipcServerOptOutAllBrokersCompletion(error: Error?)
    case ipcServerStartScheduledOperations
    case ipcServerStartScheduledOperationsCompletion(error: Error?)
    case ipcServerRunAllOperations

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
    case scanSuccess(dataBroker: String, matchesFound: Int, duration: Double, tries: Int, isImmediateOperation: Bool)
    case scanFailed(dataBroker: String, duration: Double, tries: Int, isImmediateOperation: Bool)
    case scanError(dataBroker: String, duration: Double, category: String, details: String, isImmediateOperation: Bool)

    // KPIs - engagement
    case dailyActiveUser
    case weeklyActiveUser
    case monthlyActiveUser

    // KPIs - events
    case weeklyReportScanning(hadNewMatch: Bool, hadReAppereance: Bool, scanCoverage: String)
    case weeklyReportRemovals(removals: Int)
    case scanningEventNewMatch
    case scanningEventReAppearance

    // Web UI - loading errors
    case webUILoadingStarted(environment: String)
    case webUILoadingFailed(errorCategory: String)
    case webUILoadingSuccess(environment: String)

    // Backend service errors
    case generateEmailHTTPErrorDaily(statusCode: Int, environment: String, wasOnWaitlist: Bool)
    case emptyAccessTokenDaily(environment: String, wasOnWaitlist: Bool, callSite: BackendServiceCallSite)

    // Home View
    case homeViewShowNoPermissionError
    case homeViewShowWebUI
    case homeViewShowBadPathError
    case homeViewCTAMoveApplicationClicked
    case homeViewCTAGrantPermissionClicked

    // Initial scans pixels
    // https://app.asana.com/0/1204006570077678/1206981742767458/f
    case initialScanTotalDuration(duration: Double, profileQueries: Int)
    case initialScanSiteLoadDuration(duration: Double, hasError: Bool, brokerURL: String)
    case initialScanPostLoadingDuration(duration: Double, hasError: Bool, brokerURL: String)
    case initialScanPreStartDuration(duration: Double)
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
        case .optOutFillForm: return "m_mac_dbp_macos_optout_stage_fill-form"

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
        case .generalError: return "m_mac_data_broker_error"
        case .secureVaultInitError: return "m_mac_dbp_secure_vault_init_error"
        case .secureVaultError: return "m_mac_dbp_secure_vault_error"

        case .backgroundAgentStarted: return "m_mac_dbp_background-agent_started"
        case .backgroundAgentStartedStoppingDueToAnotherInstanceRunning: return "m_mac_dbp_background-agent_started_stopping-due-to-another-instance-running"

        case .backgroundAgentRunOperationsAndStartSchedulerIfPossible: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible"
        case .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible_no-saved-profile"
        case .backgroundAgentRunOperationsAndStartSchedulerIfPossibleStartScheduledOperationsCallbackStartScheduler: return "m_mac_dbp_background-agent-run-operations-and-start-scheduler-if-possible_callback_start-scheduler"

        case .ipcServerStartSchedulerCalledByApp: return "m_mac_dbp_ipc-server_start-scheduler_called-by-app"
        case .ipcServerStartSchedulerReceivedByAgent: return "m_mac_dbp_ipc-server_start-scheduler_received-by-agent"
        case .ipcServerStartSchedulerXPCError: return "m_mac_dbp_ipc-server_start-scheduler_xpc-error"

        case .ipcServerStopSchedulerCalledByApp: return "m_mac_dbp_ipc-server_stop-scheduler_called-by-app"
        case .ipcServerStopSchedulerReceivedByAgent: return "m_mac_dbp_ipc-server_stop-scheduler_received-by-agent"
        case .ipcServerStopSchedulerXPCError: return "m_mac_dbp_ipc-server_stop-scheduler_xpc-error"

        case .ipcServerScanAllBrokersAttemptedToCallWithoutLoginItemPermissions: return "m_mac_dbp_ipc-server_scan-all-brokers_attempted-to-call-without-login-item-permissions"
        case .ipcServerScanAllBrokersAttemptedToCallInWrongDirectory: return "m_mac_dbp_ipc-server_scan-all-brokers_attempted-to-call-in-wrong-directory"
        case .ipcServerScanAllBrokersCalledByApp: return "m_mac_dbp_ipc-server_scan-all-brokers_called-by-app"
        case .ipcServerScanAllBrokersReceivedByAgent: return "m_mac_dbp_ipc-server_scan-all-brokers_received-by-agent"
        case .ipcServerScanAllBrokersXPCError: return "m_mac_dbp_ipc-server_scan-all-brokers_xpc-error"
        case .ipcServerScanAllBrokersCompletedOnAgentWithoutError: return "m_mac_dbp_ipc-server_scan-all-brokers_completed-on-agent_without-error"
        case .ipcServerScanAllBrokersCompletedOnAgentWithError: return "m_mac_dbp_ipc-server_scan-all-brokers_completed-on-agent_with-error"
        case .ipcServerScanAllBrokersCompletionCalledOnAppWithoutError: return "m_mac_dbp_ipc-server_scan-all-brokers_completion-called-on-app_without-error"
        case .ipcServerScanAllBrokersCompletionCalledOnAppWithError: return "m_mac_dbp_ipc-server_scan-all-brokers_completion-called-on-app_with-error"
        case .ipcServerScanAllBrokersInterruptedOnAgent: return "m_mac_dbp_ipc-server_scan-all-brokers_interrupted-on-agent"
        case .ipcServerScanAllBrokersCompletionCalledOnAppAfterInterruption: return "m_mac_dbp_ipc-server_scan-all-brokers_completion-called-on-app_after-interruption"

        case .ipcServerOptOutAllBrokers: return "m_mac_dbp_ipc-server_opt-out-all-brokers"
        case .ipcServerOptOutAllBrokersCompletion: return "m_mac_dbp_ipc-server_opt-out-all-brokers_completion"
        case .ipcServerStartScheduledOperations: return "m_mac_dbp_ipc-server_run-queued-operations"
        case .ipcServerStartScheduledOperationsCompletion: return "m_mac_dbp_ipc-server_run-queued-operations_completion"
        case .ipcServerRunAllOperations: return "m_mac_dbp_ipc-server_run-all-operations"

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

        case .weeklyReportScanning: return "m_mac_dbp_event_weekly-report_scanning"
        case .weeklyReportRemovals: return "m_mac_dbp_event_weekly-report_removals"
        case .scanningEventNewMatch: return "m_mac_dbp_event_scanning-events_new-match"
        case .scanningEventReAppearance: return "m_mac_dbp_event_scanning-events_re-appearance"

        case .webUILoadingStarted: return "m_mac_dbp_web_ui_loading_started"
        case .webUILoadingSuccess: return "m_mac_dbp_web_ui_loading_success"
        case .webUILoadingFailed: return "m_mac_dbp_web_ui_loading_failed"

            // Backend service errors
        case .generateEmailHTTPErrorDaily: return "m_mac_dbp_service_email-generate-http-error"
        case .emptyAccessTokenDaily: return "m_mac_dbp_service_empty-auth-token"

            // Home View
        case .homeViewShowNoPermissionError: return "m_mac_dbp_home_view_show-no-permission-error"
        case .homeViewShowWebUI: return "m_mac_dbp_home_view_show-web-ui"
        case .homeViewShowBadPathError: return "m_mac_dbp_home_view_show-bad-path-error"
        case .homeViewCTAMoveApplicationClicked: return "m_mac_dbp_home_view-cta-move-application-clicked"
        case .homeViewCTAGrantPermissionClicked: return "m_mac_dbp_home_view-cta-grant-permission-clicked"

            // Initial scans pixels
        case .initialScanTotalDuration: return "m_mac_dbp_initial_scan_duration"
        case .initialScanSiteLoadDuration: return "m_mac_dbp_scan_broker_site_loaded"
        case .initialScanPostLoadingDuration: return "m_mac_dbp_initial_scan_broker_post_loading"
        case .initialScanPreStartDuration: return "m_mac_dbp_initial_scan_pre_start_duration"
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
        case .generalError(_, let functionOccurredIn):
            return ["functionOccurredIn": functionOccurredIn]
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
        case .optOutFillForm(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmitSuccess(let dataBroker, let attemptId, let duration, let tries, let pattern):
            var params = [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.triesKey: String(tries)]
            if let pattern = pattern {
                params[Consts.pattern] = pattern
            }
            return params
        case .optOutSuccess(let dataBroker, let attemptId, let duration, let type):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.isParent: String(type.rawValue)]
        case .optOutFailure(let dataBroker, let attemptId, let duration, let stage, let tries, let pattern, let actionID):
            var params = [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.stageKey: stage, Consts.triesKey: String(tries)]
            if let pattern = pattern {
                params[Consts.pattern] = pattern
            }

            if let actionID = actionID {
                params[Consts.actionIDKey] = actionID
            }

            return params
        case .weeklyReportScanning(let hadNewMatch, let hadReAppereance, let scanCoverage):
            return [Consts.hadNewMatch: hadNewMatch ? "1" : "0", Consts.hadReAppereance: hadReAppereance ? "1" : "0", Consts.scanCoverage: scanCoverage.description]
        case .weeklyReportRemovals(let removals):
            return [Consts.removals: String(removals)]
        case .webUILoadingStarted(let environment):
            return [Consts.environmentKey: environment]
        case .webUILoadingSuccess(let environment):
            return [Consts.environmentKey: environment]
        case .webUILoadingFailed(let error):
            return [Consts.errorCategoryKey: error]
        case .backgroundAgentStarted,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                .backgroundAgentRunOperationsAndStartSchedulerIfPossibleStartScheduledOperationsCallbackStartScheduler,
                .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
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
                .monthlyActiveUser,

                .scanningEventNewMatch,
                .scanningEventReAppearance,
                .homeViewShowNoPermissionError,
                .homeViewShowWebUI,
                .homeViewShowBadPathError,
                .homeViewCTAMoveApplicationClicked,
                .homeViewCTAGrantPermissionClicked,

                .secureVaultInitError,
                .secureVaultError:
            return [:]
        case .ipcServerStartSchedulerCalledByApp,
                .ipcServerStartSchedulerReceivedByAgent,
                .ipcServerStartSchedulerXPCError,
                .ipcServerStopSchedulerCalledByApp,
                .ipcServerStopSchedulerReceivedByAgent,
                .ipcServerStopSchedulerXPCError,
                .ipcServerScanAllBrokersAttemptedToCallWithoutLoginItemPermissions,
                .ipcServerScanAllBrokersAttemptedToCallInWrongDirectory,
                .ipcServerScanAllBrokersCalledByApp,
                .ipcServerScanAllBrokersReceivedByAgent,
                .ipcServerScanAllBrokersXPCError,
                .ipcServerScanAllBrokersCompletedOnAgentWithoutError,
                .ipcServerScanAllBrokersCompletedOnAgentWithError,
                .ipcServerScanAllBrokersCompletionCalledOnAppWithoutError,
                .ipcServerScanAllBrokersCompletionCalledOnAppWithError,
                .ipcServerScanAllBrokersInterruptedOnAgent,
                .ipcServerScanAllBrokersCompletionCalledOnAppAfterInterruption,
                .ipcServerOptOutAllBrokers,
                .ipcServerOptOutAllBrokersCompletion,
                .ipcServerStartScheduledOperations,
                .ipcServerStartScheduledOperationsCompletion,
                .ipcServerRunAllOperations:
            return [Consts.bundleIDParamKey: Bundle.main.bundleIdentifier ?? "nil"]
        case .scanSuccess(let dataBroker, let matchesFound, let duration, let tries, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.matchesFoundKey: String(matchesFound), Consts.durationParamKey: String(duration), Consts.triesKey: String(tries), Consts.isImmediateOperation: isImmediateOperation.description]
        case .scanFailed(let dataBroker, let duration, let tries, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.durationParamKey: String(duration), Consts.triesKey: String(tries), Consts.isImmediateOperation: isImmediateOperation.description]
        case .scanError(let dataBroker, let duration, let category, let details, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.durationParamKey: String(duration), Consts.errorCategoryKey: category, Consts.errorDetailsKey: details, Consts.isImmediateOperation: isImmediateOperation.description]
        case .generateEmailHTTPErrorDaily(let statusCode, let environment, let wasOnWaitlist):
            return [Consts.environmentKey: environment,
                    Consts.httpCode: String(statusCode),
                    Consts.wasOnWaitlist: String(wasOnWaitlist)]
        case .emptyAccessTokenDaily(let environment, let wasOnWaitlist, let backendServiceCallSite):
            return [Consts.environmentKey: environment,
                    Consts.wasOnWaitlist: String(wasOnWaitlist),
                    Consts.backendServiceCallSite: backendServiceCallSite.rawValue]
        case .initialScanTotalDuration(let duration, let profileQueries):
            return [Consts.durationInMs: String(duration), Consts.profileQueries: String(profileQueries)]
        case .initialScanSiteLoadDuration(let duration, let hasError, let brokerURL):
            return [Consts.durationInMs: String(duration), Consts.hasError: hasError.description, Consts.brokerURL: brokerURL]
        case .initialScanPostLoadingDuration(let duration, let hasError, let brokerURL):
            return [Consts.durationInMs: String(duration), Consts.hasError: hasError.description, Consts.brokerURL: brokerURL]
        case .initialScanPreStartDuration(let duration):
            return [Consts.durationInMs: String(duration)]
        }
    }
}

public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    // swiftlint:disable:next function_body_length
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .generateEmailHTTPErrorDaily:
                PixelKit.fire(event, frequency: .daily)
            case .emptyAccessTokenDaily:
                PixelKit.fire(event, frequency: .daily)
            case .error(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .generalError(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .secureVaultInitError(let error),
                    .secureVaultError(let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .ipcServerStartSchedulerXPCError(error: let error),
                    .ipcServerStopSchedulerXPCError(error: let error),
                    .ipcServerScanAllBrokersXPCError(error: let error),
                    .ipcServerScanAllBrokersCompletedOnAgentWithError(error: let error),
                    .ipcServerScanAllBrokersCompletionCalledOnAppWithError(error: let error),
                    .ipcServerOptOutAllBrokersCompletion(error: let error),
                    .ipcServerStartScheduledOperationsCompletion(error: let error):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .dailyAndCount, includeAppVersionParameter: true)
            case .ipcServerStartSchedulerCalledByApp,
                    .ipcServerStartSchedulerReceivedByAgent,
                    .ipcServerStopSchedulerCalledByApp,
                    .ipcServerStopSchedulerReceivedByAgent,
                    .ipcServerScanAllBrokersAttemptedToCallWithoutLoginItemPermissions,
                    .ipcServerScanAllBrokersAttemptedToCallInWrongDirectory,
                    .ipcServerScanAllBrokersCalledByApp,
                    .ipcServerScanAllBrokersReceivedByAgent,
                    .ipcServerScanAllBrokersCompletedOnAgentWithoutError,
                    .ipcServerScanAllBrokersCompletionCalledOnAppWithoutError,
                    .ipcServerScanAllBrokersInterruptedOnAgent,
                    .ipcServerScanAllBrokersCompletionCalledOnAppAfterInterruption:
                PixelKit.fire(event, frequency: .dailyAndCount, includeAppVersionParameter: true)
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
                    .optOutFillForm,
                    .optOutSuccess,
                    .optOutFailure,
                    .backgroundAgentStarted,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleStartScheduledOperationsCallbackStartScheduler,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .ipcServerOptOutAllBrokers,
                    .ipcServerStartScheduledOperations,
                    .ipcServerRunAllOperations,
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
                    .monthlyActiveUser,
                    .weeklyReportScanning,
                    .weeklyReportRemovals,
                    .scanningEventNewMatch,
                    .scanningEventReAppearance,
                    .webUILoadingFailed,
                    .webUILoadingStarted,
                    .webUILoadingSuccess,
                    .initialScanTotalDuration,
                    .initialScanSiteLoadDuration,
                    .initialScanPostLoadingDuration,
                    .initialScanPreStartDuration:

                PixelKit.fire(event)

            case .homeViewShowNoPermissionError,
                    .homeViewShowWebUI,
                    .homeViewShowBadPathError,
                    .homeViewCTAMoveApplicationClicked,
                    .homeViewCTAGrantPermissionClicked:
                PixelKit.fire(event, frequency: .dailyAndCount)

            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
