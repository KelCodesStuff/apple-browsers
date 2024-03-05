//
//  PreferencesSection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI

#if SUBSCRIPTION
import Subscription
#endif

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesSectionIdentifier
    let panes: [PreferencePaneIdentifier]

    @MainActor
    static func defaultSections(includingDuckPlayer: Bool, includingSync: Bool, includingVPN: Bool) -> [PreferencesSection] {
        let regularPanes: [PreferencePaneIdentifier] = {

            var panes: [PreferencePaneIdentifier] = [.general, .appearance, .privacy, .autofill, .downloads]

            if DefaultSubscriptionFeatureAvailability().isFeatureAvailable() {
#if SUBSCRIPTION
                panes = [.privacy, .subscription, .general, .appearance, .autofill, .downloads]
#endif
            }

            if includingSync {
                if let generalIndex = panes.firstIndex(of: .general) {
                    panes.insert(.sync, at: generalIndex + 1)
                }
            }

            if includingDuckPlayer {
                panes.append(.duckPlayer)
            }

#if NETWORK_PROTECTION
            if includingVPN {
                panes.append(.vpn)
            }
#endif

            return panes
        }()

        return [
            .init(id: .regularPreferencePanes, panes: regularPanes),
            .init(id: .about, panes: [.about])
        ]
    }
}

enum PreferencesSectionIdentifier: Hashable, CaseIterable {
    case regularPreferencePanes
    case about
}

enum PreferencePaneIdentifier: String, Equatable, Hashable, Identifiable {
    case general
    case sync
    case appearance
    case privacy
#if NETWORK_PROTECTION
    case vpn
#endif
#if SUBSCRIPTION
    case subscription
#endif
    case autofill
    case downloads
    case duckPlayer = "duckplayer"
    case about

    var id: Self {
        self
    }

    init?(url: URL) {
        // manually extract path because URLs such as "about:settings" can't figure out their host or path
        for urlPrefix in [URL.settings, URL.Invalid.aboutPreferences, URL.Invalid.aboutConfig, URL.Invalid.aboutSettings, URL.Invalid.duckConfig, URL.Invalid.duckPreferences] {
            let prefix = urlPrefix.absoluteString + "/"
            guard url.absoluteString.hasPrefix(prefix) else { continue }

            let path = url.absoluteString.dropping(prefix: prefix)
            self.init(rawValue: path)
            return
        }
        return nil
    }

    @MainActor
    var displayName: String {
        switch self {
        case .general:
            return UserText.general
        case .sync:
            let isSyncBookmarksPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPaused.rawValue)
            let isSyncCredentialsPaused = UserDefaults.standard.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPaused.rawValue)
            let syncService = NSApp.delegateTyped.syncService
            let isDataSyncingDisabled = syncService?.featureFlags.contains(.dataSyncing) == false && syncService?.authState == .active
            if isSyncBookmarksPaused || isSyncCredentialsPaused || isDataSyncingDisabled {
                return UserText.sync + " ⚠️"
            }
            return UserText.sync
        case .appearance:
            return UserText.appearance
        case .privacy:
            return UserText.privacy
#if NETWORK_PROTECTION
        case .vpn:
            return UserText.vpn
#endif
#if SUBSCRIPTION
        case .subscription:
            return UserText.subscription
#endif
        case .autofill:
            return UserText.autofill
        case .downloads:
            return UserText.downloads
        case .duckPlayer:
            return UserText.duckPlayer
        case .about:
            return UserText.about
        }
    }

    var preferenceIconName: String {
        switch self {
        case .general:
            return "Rocket"
        case .sync:
            return "Sync"
        case .appearance:
            return "Appearance"
        case .privacy:
            return "Privacy"
#if NETWORK_PROTECTION
        case .vpn:
            return "VPN"
#endif
#if SUBSCRIPTION
        case .subscription:
            return "PrivacyPro"
#endif
        case .autofill:
            return "Autofill"
        case .downloads:
            return "DownloadsPreferences"
        case .duckPlayer:
            return "DuckPlayerSettings"
        case .about:
            return "About"
        }
    }
}
