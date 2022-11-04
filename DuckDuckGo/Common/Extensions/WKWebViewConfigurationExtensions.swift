//
//  WKWebViewConfigurationExtensions.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import WebKit
import Combine
import BrowserServicesKit

extension WKWebViewConfiguration {

    func applyStandardConfiguration() {
        allowsAirPlayForMediaPlayback = true
        preferences.setValue(true, forKey: "fullScreenEnabled")
        preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        preferences.setValue(false, forKey: "backspaceKeyNavigationEnabled")
        if WKNavigationAction.supportsIsUserInitiated {
            preferences.javaScriptCanOpenWindowsAutomatically = true
        } else {
            assertionFailure("WKNavigationAction does not respond to _isUserInitiated")
            preferences.javaScriptCanOpenWindowsAutomatically = false
        }
        preferences.isFraudulentWebsiteWarningEnabled = false
        
        if urlSchemeHandler(forURLScheme: PrivatePlayer.privatePlayerScheme) == nil {
            setURLSchemeHandler(PrivatePlayerSchemeHandler(), forURLScheme: PrivatePlayer.privatePlayerScheme)
        }

        self.userContentController = UserContentController()
        self.processPool.geolocationProvider = GeolocationProvider(processPool: self.processPool)
     }

}

extension UserContentController {

    convenience init(privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager) {
        self.init(assetsPublisher: ContentBlocking.shared.userContentUpdating.userContentBlockingAssets,
                  privacyConfigurationManager: privacyConfigurationManager)
    }

}
