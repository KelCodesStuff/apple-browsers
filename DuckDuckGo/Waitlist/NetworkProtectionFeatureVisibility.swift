//
//  NetworkProtectionFeatureVisibility.swift
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
import Combine
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionUI
import LoginItems
import PixelKit
import Subscription

protocol NetworkProtectionFeatureVisibility {
    var isInstalled: Bool { get }

    func canStartVPN() async throws -> Bool
    func isVPNVisible() -> Bool
    func shouldUninstallAutomatically() -> Bool
    func disableForAllUsers() async
    @discardableResult
    func disableIfUserHasNoAccess() async -> Bool

    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> { get }
}

struct DefaultNetworkProtectionVisibility: NetworkProtectionFeatureVisibility {
    private static var subscriptionAuthTokenPrefix: String { "ddg:" }
    private let featureDisabler: NetworkProtectionFeatureDisabling
    private let featureOverrides: WaitlistBetaOverriding
    private let networkProtectionFeatureActivation: NetworkProtectionFeatureActivation
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private let defaults: UserDefaults
    let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
    let accountManager: AccountManager

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         networkProtectionFeatureActivation: NetworkProtectionFeatureActivation = NetworkProtectionKeychainTokenStore(),
         featureOverrides: WaitlistBetaOverriding = DefaultWaitlistBetaOverrides(),
         featureDisabler: NetworkProtectionFeatureDisabling = NetworkProtectionFeatureDisabler(),
         defaults: UserDefaults = .netP,
         log: OSLog = .networkProtection) {

        self.privacyConfigurationManager = privacyConfigurationManager
        self.networkProtectionFeatureActivation = networkProtectionFeatureActivation
        self.featureDisabler = featureDisabler
        self.featureOverrides = featureOverrides
        self.defaults = defaults
        self.accountManager = AccountManager(subscriptionAppGroup: subscriptionAppGroup)
    }

    var isInstalled: Bool {
        LoginItem.vpnMenu.status.isInstalled
    }

    /// Whether the user can start the VPN.
    ///
    /// For beta users this means they have an auth token.
    /// For subscription users this means they have entitlements.
    ///
    func canStartVPN() async throws -> Bool {
        guard subscriptionFeatureAvailability.isFeatureAvailable else {
            return false
        }

        switch await accountManager.hasEntitlement(for: .networkProtection) {
        case .success(let hasEntitlement):
            return hasEntitlement
        case .failure(let error):
            throw error
        }
    }

    /// Whether the user can see the VPN entry points in the UI.
    ///
    /// For beta users this means they have an auth token.
    /// For subscription users this means they are authenticated.
    ///
    func isVPNVisible() -> Bool {
        guard subscriptionFeatureAvailability.isFeatureAvailable else {
            return false
        }

        return accountManager.isUserAuthenticated
    }

    /// We've had to add this method because accessing the singleton in app delegate is crashing the integration tests.
    ///
    var subscriptionFeatureAvailability: DefaultSubscriptionFeatureAvailability {
        DefaultSubscriptionFeatureAvailability()
    }

    /// Returns whether the VPN should be uninstalled automatically.
    /// This is only true when the user is not an Easter Egg user, the waitlist test has ended, and the user is onboarded.
    func shouldUninstallAutomatically() -> Bool {
        return subscriptionFeatureAvailability.isFeatureAvailable && !accountManager.isUserAuthenticated && LoginItem.vpnMenu.status.isInstalled
    }

    /// Whether the user is fully onboarded
    /// 
    var isOnboarded: Bool {
        defaults.networkProtectionOnboardingStatus == .completed
    }

    /// A publisher for the onboarding status
    ///
    var onboardStatusPublisher: AnyPublisher<OnboardingStatus, Never> {
        defaults.networkProtectionOnboardingStatusPublisher
    }

    func disableForAllUsers() async {
        await featureDisabler.disable(uninstallSystemExtension: false)
    }

    /// A method meant to be called safely from different places to disable the VPN if the user isn't meant to have access to it.
    ///
    @discardableResult
    func disableIfUserHasNoAccess() async -> Bool {
        guard shouldUninstallAutomatically() else {
            return false
        }

        await disableForAllUsers()
        return true
    }
}
