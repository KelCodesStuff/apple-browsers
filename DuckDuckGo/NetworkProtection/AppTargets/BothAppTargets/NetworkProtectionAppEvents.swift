//
//  NetworkProtectionAppEvents.swift
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

#if NETWORK_PROTECTION
import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionUI
import NetworkProtectionIPC
import NetworkExtension

/// Implements the sequence of steps that the VPN needs to execute when the App starts up.
///
final class NetworkProtectionAppEvents {

    // MARK: - Legacy VPN Item and Extension

#if NETP_SYSTEM_EXTENSION
#if DEBUG
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.debug"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.debug.network-protection-extension"
#elseif REVIEW
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.review"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.review.network-protection-extension"
#else
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.network-protection-extension"
#endif // DEBUG || REVIEW || RELEASE
#endif // NETP_SYSTEM_EXTENSION

    // MARK: - Feature Visibility

    private let featureVisibility: NetworkProtectionFeatureVisibility
    private let featureDisabler: NetworkProtectionFeatureDisabling
    private let defaults: UserDefaults

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(),
         featureDisabler: NetworkProtectionFeatureDisabling = NetworkProtectionFeatureDisabler(),
         defaults: UserDefaults = .netP) {

        self.defaults = defaults
        self.featureDisabler = featureDisabler
        self.featureVisibility = featureVisibility
    }

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()

        Task { @MainActor in
            let disabled = await featureVisibility.disableIfUserHasNoAccess()

            guard !disabled else {
                return
            }

            restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
            refreshNetworkProtectionServers()
        }
    }

    /// Call this method when the app becomes active to run the associated NetP logic.
    ///
    func applicationDidBecomeActive() {
        Task { @MainActor in
            await featureVisibility.disableIfUserHasNoAccess()
        }
    }

    private func restartNetworkProtectionIfVersionChanged(using loginItemsManager: LoginItemsManager) {
        // We want to restart the VPN menu app to make sure it's always on the latest.
        restartNetworkProtectionMenu(using: loginItemsManager)
    }

    private func restartNetworkProtectionMenu(using loginItemsManager: LoginItemsManager) {
        guard loginItemsManager.isAnyEnabled(LoginItemsManager.networkProtectionLoginItems) else {
            return
        }

        loginItemsManager.restartLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)
    }

    /// Fetches a new list of VPN servers, and updates the existing set.
    ///
    private func refreshNetworkProtectionServers() {
        Task {
            let serverCount: Int
            do {
                serverCount = try await NetworkProtectionDeviceManager.create().refreshServerList().count
            } catch {
                os_log("Failed to update DuckDuckGo VPN servers", log: .networkProtection, type: .error)
                return
            }

            os_log("Successfully updated DuckDuckGo VPN servers; total server count = %{public}d", log: .networkProtection, serverCount)
        }
    }
}

#endif
