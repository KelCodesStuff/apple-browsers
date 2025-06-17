//
//  SettingsPrivacyProtectionsView.swift
//  DuckDuckGo
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

import SwiftUI
import UIKit
import Core
import DesignResourcesKit
import DesignResourcesKitIcons

struct SettingsPrivacyProtectionsView: View {

    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        Section(header: Text("Privacy Protections")) {
            if !viewModel.shouldShowSetAsDefaultBrowser  {
                // Default Browser
                SettingsCellView(label: UserText.defaultBrowser,
                                 image: Image(uiImage: DesignSystemImages.Color.Size24.defaultBrowserMobile),
                                 action: { viewModel.setAsDefaultBrowser() },
                                 webLinkIndicator: true,
                                 isButton: true)
            }
            // Private Search
            NavigationLink(destination: PrivateSearchView().environmentObject(viewModel)) {
                SettingsCellView(label: UserText.privateSearch,
                                 image: Image(uiImage: DesignSystemImages.Color.Size24.findSearch),
                                 statusIndicator: StatusIndicatorView(status: .on))
            }

            // Web Tracking Protection
            NavigationLink(destination: WebTrackingProtectionView().environmentObject(viewModel)) {
                SettingsCellView(label: UserText.webTrackingProtection,
                                 image: Image(uiImage: DesignSystemImages.Color.Size24.shield),
                                 statusIndicator: StatusIndicatorView(status: .on))
            }

            // Threat Protection
            NavigationLink(destination: ThreatProtectionView().environmentObject(viewModel)) {
                SettingsCellView(label: UserText.threatProtection,
                                 image: Image(.radarColor24),
                                 statusIndicator: StatusIndicatorView(status: .on))
            }

            // Cookie Pop-Up Protection
            NavigationLink(destination: CookiePopUpProtectionView().environmentObject(viewModel)) {
                SettingsCellView(label: UserText.cookiePopUpProtection,
                                 image: Image(uiImage: DesignSystemImages.Color.Size24.cookie),
                                 statusIndicator: StatusIndicatorView(status: viewModel.cookiePopUpProtectionStatus))
            }

            // Email Protection
            NavigationLink(destination: EmailProtectionView().environmentObject(viewModel)) {
                SettingsCellView(label: UserText.emailProtection,
                                 image: Image(uiImage: DesignSystemImages.Color.Size24.emailProtection),
                                 statusIndicator: StatusIndicatorView(status: viewModel.emailProtectionStatus))
            }
        }

    }

}
