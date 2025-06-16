//
//  NetworkProtectionNavBarPopoverManager.swift
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

import AppLauncher
import AppKit
import BrowserServicesKit
import Combine
import Common
import FeatureFlags
import Foundation
import LoginItems
import VPN
import NetworkProtectionIPC
import NetworkProtectionProxy
import NetworkProtectionUI
import os.log
import Subscription
import SwiftUI
import VPNAppState
import VPNAppLauncher

protocol NetworkProtectionIPCClient {
    var ipcStatusObserver: ConnectionStatusObserver { get }
    var ipcServerInfoObserver: ConnectionServerInfoObserver { get }
    var ipcConnectionErrorObserver: ConnectionErrorObserver { get }
    var ipcDataVolumeObserver: DataVolumeObserver { get }

    func start(completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping (Error?) -> Void)
    func command(_ command: VPNCommand) async throws
}

extension VPNControllerXPCClient: NetworkProtectionIPCClient {
    public var ipcStatusObserver: any VPN.ConnectionStatusObserver { connectionStatusObserver }
    public var ipcServerInfoObserver: any VPN.ConnectionServerInfoObserver { serverInfoObserver }
    public var ipcConnectionErrorObserver: any VPN.ConnectionErrorObserver { connectionErrorObserver }
    public var ipcDataVolumeObserver: any VPN.DataVolumeObserver { dataVolumeObserver }
}

@MainActor
final class NetworkProtectionNavBarPopoverManager: NetPPopoverManager {
    private var networkProtectionPopover: NetworkProtectionPopover?
    let ipcClient: NetworkProtectionIPCClient
    let vpnUninstaller: VPNUninstalling
    private let vpnUIPresenting: VPNUIPresenting
    private let proxySettings: TransparentProxySettings

    @Published
    private var siteInfo: ActiveSiteInfo?
    private let activeSitePublisher: ActiveSiteInfoPublisher
    private let featureFlagger = NSApp.delegateTyped.featureFlagger
    private var cancellables = Set<AnyCancellable>()

    init(ipcClient: VPNControllerXPCClient,
         vpnUninstaller: VPNUninstalling,
         vpnUIPresenting: VPNUIPresenting,
         proxySettings: TransparentProxySettings = .init(defaults: .netP)) {

        self.ipcClient = ipcClient
        self.vpnUninstaller = vpnUninstaller
        self.vpnUIPresenting = vpnUIPresenting
        self.proxySettings = proxySettings

        let activeDomainPublisher = ActiveDomainPublisher(windowControllersManager: Application.appDelegate.windowControllersManager)

        activeSitePublisher = ActiveSiteInfoPublisher(
            activeDomainPublisher: activeDomainPublisher.eraseToAnyPublisher(),
            proxySettings: proxySettings)

        subscribeToCurrentSitePublisher()
    }

    private func subscribeToCurrentSitePublisher() {
        activeSitePublisher
            .assign(to: \.siteInfo, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    var isShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    @MainActor
    func manageExcludedApps() {
        vpnUIPresenting.showVPNAppExclusions()
    }

    @MainActor
    func manageExcludedSites() {
        vpnUIPresenting.showVPNDomainExclusions()
    }

    private func statusViewSubmenu() -> [StatusBarMenu.MenuItem] {
        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
        let vpnAppState = VPNAppState(defaults: .netP)

        var menuItems = [StatusBarMenu.MenuItem]()

        if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
            menuItems.append(
                .text(icon: Image(.settings16), title: UserText.vpnStatusViewVPNSettingsMenuItemTitle, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
                }))
        }

        if vpnAppState.isUsingSystemExtension {
            menuItems.append(contentsOf: [
                .textWithDetail(
                    icon: Image(.window16),
                    title: UserText.vpnStatusViewExcludedAppsMenuItemTitle,
                    detail: "(\(proxySettings.excludedAppsMinusDBPAgent.count))",
                    action: { [weak self] in
                        self?.manageExcludedApps()
                    }),
                .textWithDetail(
                    icon: Image(.globe16),
                    title: UserText.vpnStatusViewExcludedDomainsMenuItemTitle,
                    detail: "(\(proxySettings.excludedDomains.count))",
                    action: { [weak self] in
                        self?.manageExcludedSites()
                    }),
                .divider()
            ])
        }

        menuItems.append(contentsOf: [
            .text(icon: Image(.help16), title: UserText.vpnStatusViewFAQMenuItemTitle, action: {
                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
            }),
            .text(icon: Image(.support16), title: UserText.vpnStatusViewSendFeedbackMenuItemTitle, action: {
                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
            })
        ])

        return menuItems
    }

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover {

        /// Since the favicon doesn't have a publisher we force refreshing here
        activeSitePublisher.refreshActiveSiteInfo()

        let popover: NSPopover = {
            let vpnAppState = VPNAppState(defaults: .netP)
            let vpnSettings = VPNSettings(defaults: .netP)
            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.ipcStatusObserver,
                serverInfoObserver: ipcClient.ipcServerInfoObserver,
                connectionErrorObserver: ipcClient.ipcConnectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications(),
                dataVolumeObserver: ipcClient.ipcDataVolumeObserver,
                knownFailureObserver: KnownFailureObserverThroughDistributedNotifications()
            )

            let onboardingStatusPublisher = UserDefaults.netP.networkProtectionOnboardingStatusPublisher
            let vpnURLEventHandler = VPNURLEventHandler()
            let uiActionHandler = VPNUIActionHandler(
                vpnURLEventHandler: vpnURLEventHandler,
                tunnelController: controller,
                proxySettings: proxySettings,
                vpnAppState: vpnAppState)

            let connectionStatusPublisher = CurrentValuePublisher(
                initialValue: statusReporter.statusObserver.recentValue,
                publisher: statusReporter.statusObserver.publisher)

            let activeSitePublisher = CurrentValuePublisher(
                initialValue: siteInfo,
                publisher: $siteInfo.eraseToAnyPublisher())

            let siteTroubleshootingViewModel = SiteTroubleshootingView.Model(
                connectionStatusPublisher: connectionStatusPublisher,
                activeSitePublisher: activeSitePublisher,
                uiActionHandler: uiActionHandler)

            let menuItems = { [weak self] () -> [NetworkProtectionStatusView.Model.MenuItem] in
                guard let self else { return [] }
                return statusViewSubmenu()
            }

#if APPSTORE
            let isExtensionUpdateOfferedPublisher: CurrentValuePublisher<Bool, Never> = {
                let initialValue = featureFlagger.isFeatureOn(.networkProtectionAppStoreSysexMessage)
                    && !vpnAppState.isUsingSystemExtension

                let publisher = vpnAppState.isUsingSystemExtensionPublisher
                    .map { [featureFlagger] value in
                        featureFlagger.isFeatureOn(.networkProtectionAppStoreSysexMessage) && !value
                    }.eraseToAnyPublisher()

                return CurrentValuePublisher(initialValue: initialValue, publisher: publisher)
            }()
#else
            let isExtensionUpdateOfferedPublisher = CurrentValuePublisher(initialValue: false, publisher: Just(false).eraseToAnyPublisher())
#endif

            let statusViewModel = NetworkProtectionStatusView.Model(
                controller: controller,
                onboardingStatusPublisher: onboardingStatusPublisher,
                statusReporter: statusReporter,
                uiActionHandler: uiActionHandler,
                menuItems: menuItems,
                agentLoginItem: LoginItem.vpnMenu,
                isExtensionUpdateOfferedPublisher: isExtensionUpdateOfferedPublisher,
                isMenuBarStatusView: false,
                userDefaults: .netP,
                locationFormatter: DefaultVPNLocationFormatter(),
                uninstallHandler: { [weak self] reason in

                    let showNotification = reason == .expiration

                    try? await self?.vpnUninstaller.uninstall(
                        removeSystemExtension: true,
                        showNotification: showNotification)
                })

            let tipsModel = VPNTipsModel(statusObserver: statusReporter.statusObserver,
                                         activeSitePublisher: activeSitePublisher,
                                         forMenuApp: false,
                                         vpnAppState: vpnAppState,
                                         vpnSettings: vpnSettings,
                                         proxySettings: proxySettings,
                                         logger: Logger(subsystem: "DuckDuckGo", category: "TipKit"))

            let popover = NetworkProtectionPopover(
                statusViewModel: statusViewModel,
                statusReporter: statusReporter,
                siteTroubleshootingViewModel: siteTroubleshootingViewModel,
                tipsModel: tipsModel,
                debugInformationViewModel: DebugInformationViewModel(showDebugInformation: false))
            popover.delegate = delegate

            networkProtectionPopover = popover
            return popover
        }()

        show(popover, positionedBelow: view)
        return popover
    }

    private func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover? {
        if let networkProtectionPopover, networkProtectionPopover.isShown {
            networkProtectionPopover.close()
            self.networkProtectionPopover = nil

            return nil
        } else {
            return show(positionedBelow: view, withDelegate: delegate)
        }
    }

    func close() {
        networkProtectionPopover?.close()
        networkProtectionPopover = nil
    }
}
