//
//  AboutModel.swift
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

import SwiftUI
import Common

final class AboutModel: ObservableObject, PreferencesTabOpening {
    let appVersion = AppVersion()

#if NETWORK_PROTECTION
    private let netPInvitePresenter: NetworkProtectionInvitePresenting
#endif

#if NETWORK_PROTECTION
    init(netPInvitePresenter: NetworkProtectionInvitePresenting) {
        self.netPInvitePresenter = netPInvitePresenter
    }
#else
    init() {}
#endif

    let displayableAboutURL: String = URL.aboutDuckDuckGo
        .toString(decodePunycode: false, dropScheme: true, dropTrailingSlash: false)

    @MainActor
    func openFeedbackForm() {
        FeedbackPresenter.presentFeedbackForm()
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

#if NETWORK_PROTECTION
    func displayNetPInvite() {
        netPInvitePresenter.present()
    }
#endif
}
