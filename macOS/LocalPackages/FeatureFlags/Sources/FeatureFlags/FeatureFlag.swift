//
//  FeatureFlag.swift
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
import BrowserServicesKit

public enum FeatureFlag: String, CaseIterable {
    case debugMenu
    case sslCertificatesBypass
    case maliciousSiteProtection
    case scamSiteProtection

    /// Add experimental atb parameter to SERP queries for internal users to display Privacy Reminder
    /// https://app.asana.com/0/1199230911884351/1205979030848528/f
    case appendAtbToSerpQueries

    // https://app.asana.com/0/1206488453854252/1207136666798700/f
    case freemiumDBP

    case contextualOnboarding

    // https://app.asana.com/0/1201462886803403/1208030658792310/f
    case unknownUsernameCategorization

    case credentialsImportPromotionForExistingUsers

    /// https://app.asana.com/0/0/1209402073283584
    case networkProtectionAppStoreSysex

    /// https://app.asana.com/0/1203108348835387/1209710972679271/f
    case networkProtectionAppStoreSysexMessage

    /// https://app.asana.com/0/1204186595873227/1206489252288889
    case networkProtectionRiskyDomainsProtection

    /// https://app.asana.com/0/1201048563534612/1208850443048685/f
    case historyView

    case autoUpdateInDEBUG
    case updatesWontAutomaticallyRestartApp

    case autofillPartialFormSaves
    case autocompleteTabs
    case webExtensions
    case syncSeamlessAccountSwitching

    /// SAD & ATT Prompts: https://app.asana.com/1/137249556945/project/1206329551987282/task/1210225579353384?focus=true
    case scheduledSetDefaultBrowserAndAddToDockPrompts

    /// https://app.asana.com/0/72649045549333/1207991044706236/f
    case privacyProAuthV2

    // Demonstrative cases for default value. Remove once a real-world feature/subfeature is added
    case failsafeExampleCrossPlatformFeature
    case failsafeExamplePlatformSpecificSubfeature

    /// https://app.asana.com/0/72649045549333/1209793701087222/f
    case visualUpdates
    case visualUpdatesInternalOnly

    /// https://app.asana.com/1/137249556945/project/72649045549333/task/1209227311680179?focus=true
    case tabCrashDebugging

    /// https://app.asana.com/1/137249556945/project/72649045549333/task/1209227311680179?focus=true
    case tabCrashRecovery

    /// https://app.asana.com/1/137249556945/project/1148564399326804/task/1209499005452053?focus=true
    case delayedWebviewPresentation

    /// https://app.asana.com/1/137249556945/project/72649045549333/task/1205508328452434?focus=true
    case dbpRemoteBrokerDelivery

    /// https://app.asana.com/1/137249556945/project/72649045549333/task/1210081345713964?focus=true
    case syncSetupBarcodeIsUrlBased

    /// https://app.asana.com/1/137249556945/project/414235014887631/task/1210325960030113?focus=true
    case exchangeKeysToSyncWithAnotherDevice

    /// https://app.asana.com/1/137249556945/project/72649045549333/task/1210081345713964?focus=true
    case canScanUrlBasedSyncSetupBarcodes

    /// https://app.asana.com/1/137249556945/project/1206488453854252/task/1210052464460517?focus=true
    case privacyProFreeTrial

	/// https://app.asana.com/1/137249556945/project/1204186595873227/task/1210181044180012?focus=true
    case paidAIChat

    /// https://app.asana.com/1/137249556945/task/1210330600670666
    case removeWWWInCanonicalizationInThreatProtection

    /// https://app.asana.com/1/137249556945/project/1209671977594486/task/1210410403692636?focus=true
    case aiChatSidebar

    /// https://app.asana.com/1/137249556945/project/1201899738287924/task/1210012162616039?focus=true
    case aiChatTextSummarization

    /// https://app.asana.com/1/137249556945/project/1206580121312550/task/1209808389662317?focus=true
    case osSupportForceUnsupportedMessage

    /// https://app.asana.com/1/137249556945/project/1206580121312550/task/1209808389662317?focus=true
    case osSupportForceWillSoonDropSupportMessage

    /// https://app.asana.com/1/137249556945/project/1206580121312550/task/1209808389662317?focus=true
    case willSoonDropBigSurSupport

    /// https://app.asana.com/1/137249556945/project/1201048563534612/task/1210493210455717?focus=true
    case shortHistoryMenu
}

extension FeatureFlag: FeatureFlagDescribing {
    public var defaultValue: Bool {
        switch self {
        case .failsafeExampleCrossPlatformFeature, .failsafeExamplePlatformSpecificSubfeature, .removeWWWInCanonicalizationInThreatProtection, .visualUpdatesInternalOnly:
            true
        default:
            false
        }
    }

    public var cohortType: (any FeatureFlagCohortDescribing.Type)? {
        switch self {
        default:
            return nil
        }
    }

    public var supportsLocalOverriding: Bool {
        switch self {
        case .autofillPartialFormSaves,
                .autocompleteTabs,
                .networkProtectionAppStoreSysex,
                .networkProtectionAppStoreSysexMessage,
                .networkProtectionRiskyDomainsProtection,
                .syncSeamlessAccountSwitching,
                .historyView,
                .webExtensions,
                .autoUpdateInDEBUG,
                .updatesWontAutomaticallyRestartApp,
                .privacyProAuthV2,
                .scamSiteProtection,
                .failsafeExampleCrossPlatformFeature,
                .failsafeExamplePlatformSpecificSubfeature,
                .visualUpdates,
                .visualUpdatesInternalOnly,
                .tabCrashDebugging,
                .tabCrashRecovery,
                .maliciousSiteProtection,
                .delayedWebviewPresentation,
                .syncSetupBarcodeIsUrlBased,
                .paidAIChat,
                .exchangeKeysToSyncWithAnotherDevice,
                .canScanUrlBasedSyncSetupBarcodes,
				.privacyProFreeTrial,
                .removeWWWInCanonicalizationInThreatProtection,
                .osSupportForceUnsupportedMessage,
                .osSupportForceWillSoonDropSupportMessage,
                .willSoonDropBigSurSupport,
				.aiChatSidebar,
                .aiChatTextSummarization,
                .shortHistoryMenu:
            return true
        case .debugMenu,
                .sslCertificatesBypass,
                .appendAtbToSerpQueries,
                .freemiumDBP,
                .contextualOnboarding,
                .unknownUsernameCategorization,
                .credentialsImportPromotionForExistingUsers,
                .dbpRemoteBrokerDelivery,
                .scheduledSetDefaultBrowserAndAddToDockPrompts:
            return false
        }
    }

    public var source: FeatureFlagSource {
        switch self {
        case .debugMenu:
            return .internalOnly()
        case .appendAtbToSerpQueries:
            return .internalOnly()
        case .sslCertificatesBypass:
            return .remoteReleasable(.subfeature(SslCertificatesSubfeature.allowBypass))
        case .unknownUsernameCategorization:
            return .remoteReleasable(.subfeature(AutofillSubfeature.unknownUsernameCategorization))
        case .freemiumDBP:
            return .remoteReleasable(.subfeature(DBPSubfeature.freemium))
        case .maliciousSiteProtection:
            return .remoteReleasable(.subfeature(MaliciousSiteProtectionSubfeature.onByDefault))
        case .contextualOnboarding:
            return .remoteReleasable(.feature(.contextualOnboarding))
        case .credentialsImportPromotionForExistingUsers:
            return .remoteReleasable(.subfeature(AutofillSubfeature.credentialsImportPromotionForExistingUsers))
        case .networkProtectionAppStoreSysex:
            return .remoteReleasable(.subfeature(NetworkProtectionSubfeature.appStoreSystemExtension))
        case .networkProtectionAppStoreSysexMessage:
            return .remoteReleasable(.subfeature(NetworkProtectionSubfeature.appStoreSystemExtensionMessage))
        case .historyView:
            return .remoteReleasable(.subfeature(HTMLHistoryPageSubfeature.isLaunched))
        case .autoUpdateInDEBUG:
            return .disabled
        case .updatesWontAutomaticallyRestartApp:
            return .internalOnly()
        case .autofillPartialFormSaves:
            return .remoteReleasable(.subfeature(AutofillSubfeature.partialFormSaves))
        case .autocompleteTabs:
            return .remoteReleasable(.feature(.autocompleteTabs))
        case .webExtensions:
            return .internalOnly()
        case .syncSeamlessAccountSwitching:
            return .remoteReleasable(.subfeature(SyncSubfeature.seamlessAccountSwitching))
        case .scamSiteProtection:
            return .remoteReleasable(.subfeature(MaliciousSiteProtectionSubfeature.scamProtection))
        case .networkProtectionRiskyDomainsProtection:
            return .remoteReleasable(.subfeature(NetworkProtectionSubfeature.riskyDomainsProtection))
        case .scheduledSetDefaultBrowserAndAddToDockPrompts:
            return .remoteReleasable(.subfeature(SetAsDefaultAndAddToDockSubfeature.scheduledDefaultBrowserAndDockPrompts))
        case .privacyProAuthV2:
            return .remoteReleasable(.subfeature(PrivacyProSubfeature.privacyProAuthV2))
        case .failsafeExampleCrossPlatformFeature:
            return .remoteReleasable(.feature(.intentionallyLocalOnlyFeatureForTests))
        case .failsafeExamplePlatformSpecificSubfeature:
            return .remoteReleasable(.subfeature(MacOSBrowserConfigSubfeature.intentionallyLocalOnlySubfeatureForTests))
        case .visualUpdates:
            return .remoteReleasable(.subfeature(ExperimentalThemingSubfeature.visualUpdates))
        case .visualUpdatesInternalOnly:
            return .internalOnly()
        case .tabCrashDebugging:
            return .disabled
        case .tabCrashRecovery:
            return .remoteReleasable(.feature(.tabCrashRecovery))
        case .delayedWebviewPresentation:
            return .remoteReleasable(.feature(.delayedWebviewPresentation))
        case .dbpRemoteBrokerDelivery:
            return .remoteReleasable(.subfeature(DBPSubfeature.remoteBrokerDelivery))
        case .syncSetupBarcodeIsUrlBased:
            return .remoteReleasable(.subfeature(SyncSubfeature.syncSetupBarcodeIsUrlBased))
        case .exchangeKeysToSyncWithAnotherDevice:
            return .remoteReleasable(.subfeature(SyncSubfeature.exchangeKeysToSyncWithAnotherDevice))
        case .canScanUrlBasedSyncSetupBarcodes:
            return .remoteReleasable(.subfeature(SyncSubfeature.canScanUrlBasedSyncSetupBarcodes))
        case .privacyProFreeTrial:
            return .remoteReleasable(.subfeature(PrivacyProSubfeature.privacyProFreeTrial))
        case .paidAIChat:
			return .disabled
        case .removeWWWInCanonicalizationInThreatProtection:
            return .remoteReleasable(.subfeature(MaliciousSiteProtectionSubfeature.removeWWWInCanonicalization))
        case .aiChatSidebar:
            return .internalOnly()
        case .aiChatTextSummarization:
            return .remoteReleasable(.subfeature(AIChatSubfeature.textSummarization))
        case .osSupportForceUnsupportedMessage:
            return .disabled
        case .osSupportForceWillSoonDropSupportMessage:
            return .disabled
        case .willSoonDropBigSurSupport:
            return .internalOnly()
        case .shortHistoryMenu:
            return .remoteReleasable(.feature(.shortHistoryMenu))
        }
    }
}

public extension FeatureFlagger {

    func isFeatureOn(_ featureFlag: FeatureFlag) -> Bool {
        isFeatureOn(for: featureFlag)
    }
}
