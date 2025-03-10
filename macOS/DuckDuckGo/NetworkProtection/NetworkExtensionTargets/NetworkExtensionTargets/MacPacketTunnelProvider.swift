//
//  MacPacketTunnelProvider.swift
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
import Combine
import Common
import NetworkProtection
import NetworkExtension
import Networking
import PixelKit
import Subscription
import os.log
import WireGuard

final class MacPacketTunnelProvider: PacketTunnelProvider {

    var accountManager: (any AccountManager)?

    static var isAppex: Bool {
#if NETP_SYSTEM_EXTENSION
        false
#else
        true
#endif
    }

    static var subscriptionsAppGroup: String? {
        isAppex ? Bundle.main.appGroup(bundle: .subs) : nil
    }

    // MARK: - Additional Status Info

    /// Holds the date when the status was last changed so we can send it out as additional information
    /// in our status-change notifications.
    ///
    private var lastStatusChangeDate = Date()

    // MARK: - Notifications: Observation Tokens

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Error Reporting

    private static func networkProtectionDebugEvents(controllerErrorStore: NetworkProtectionTunnelErrorStore) -> EventMapping<NetworkProtectionError> {
        return EventMapping { event, _, _, _ in
            let domainEvent: NetworkProtectionPixelEvent
#if DEBUG
            // Makes sure we see the error in the yellow NetP alert.
            controllerErrorStore.lastErrorMessage = "[Debug] Error event: \(event.localizedDescription)"
#endif
            switch event {
            case .noServerRegistrationInfo:
                domainEvent = .networkProtectionTunnelConfigurationNoServerRegistrationInfo
            case .couldNotSelectClosestServer:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotSelectClosestServer
            case .couldNotGetPeerPublicKey:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
            case .couldNotGetPeerHostName:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerHostName
            case .couldNotGetInterfaceAddressRange:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange
            case .failedToFetchServerList(let eventError):
                domainEvent = .networkProtectionClientFailedToFetchServerList(eventError)
            case .failedToParseServerListResponse:
                domainEvent = .networkProtectionClientFailedToParseServerListResponse
            case .failedToEncodeRegisterKeyRequest:
                domainEvent = .networkProtectionClientFailedToEncodeRegisterKeyRequest
            case .failedToFetchRegisteredServers(let eventError):
                domainEvent = .networkProtectionClientFailedToFetchRegisteredServers(eventError)
            case .failedToParseRegisteredServersResponse:
                domainEvent = .networkProtectionClientFailedToParseRegisteredServersResponse
            case .invalidAuthToken:
                domainEvent = .networkProtectionClientInvalidAuthToken
            case .serverListInconsistency:
                return
            case .failedToCastKeychainValueToData(let field):
                domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
            case .keychainReadError(let field, let status):
                domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
            case .keychainWriteError(let field, let status):
                domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
            case .keychainUpdateError(let field, let status):
                domainEvent = .networkProtectionKeychainUpdateError(field: field, status: status)
            case .keychainDeleteError(let status):
                domainEvent = .networkProtectionKeychainDeleteError(status: status)
            case .wireGuardCannotLocateTunnelFileDescriptor:
                domainEvent = .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor
            case .wireGuardInvalidState(let reason):
                domainEvent = .networkProtectionWireguardErrorInvalidState(reason: reason)
            case .wireGuardDnsResolution:
                domainEvent = .networkProtectionWireguardErrorFailedDNSResolution
            case .wireGuardSetNetworkSettings(let error):
                domainEvent = .networkProtectionWireguardErrorCannotSetNetworkSettings(error)
            case .startWireGuardBackend(let error):
                domainEvent = .networkProtectionWireguardErrorCannotStartWireguardBackend(error)
            case .setWireguardConfig(let error):
                domainEvent = .networkProtectionWireguardErrorCannotSetWireguardConfig(error)
            case .noAuthTokenFound:
                domainEvent = .networkProtectionNoAuthTokenFoundError
            case .failedToFetchServerStatus(let error):
                domainEvent = .networkProtectionClientFailedToFetchServerStatus(error)
            case .failedToParseServerStatusResponse(let error):
                domainEvent = .networkProtectionClientFailedToParseServerStatusResponse(error)
            case .unhandledError(function: let function, line: let line, error: let error):
                domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
            case .failedToFetchLocationList,
                    .failedToParseLocationListResponse:
                // Needs Privacy triage for macOS Geoswitching pixels
                return
            case .vpnAccessRevoked:
                return
            }

            PixelKit.fire(domainEvent, frequency: .legacyDailyAndCount, includeAppVersionParameter: true)
        }
    }

    private let notificationCenter: NetworkProtectionNotificationCenter = DistributedNotificationCenter.default()

    // MARK: - PacketTunnelProvider.Event reporting

    private static var vpnLogger = VPNLogger()

    private static var packetTunnelProviderEvents: EventMapping<PacketTunnelProvider.Event> = .init { event, _, _, _ in

#if NETP_SYSTEM_EXTENSION
        let defaults = UserDefaults.standard
#else
        let defaults = UserDefaults.netP
#endif
        switch event {
        case .userBecameActive:
            PixelKit.fire(
                NetworkProtectionPixelEvent.networkProtectionActiveUser,
                frequency: .legacyDaily,
                withAdditionalParameters: [PixelKit.Parameters.vpnCohort: PixelKit.cohort(from: defaults.vpnFirstEnabled)],
                includeAppVersionParameter: true)
        case .connectionTesterStatusChange(let status, let server):
            vpnLogger.log(status, server: server)

            switch status {
            case .failed(let duration):
                let pixel: NetworkProtectionPixelEvent = {
                    switch duration {
                    case .immediate:
                        return .networkProtectionConnectionTesterFailureDetected(server: server)
                    case .extended:
                        return .networkProtectionConnectionTesterExtendedFailureDetected(server: server)
                    }
                }()

                PixelKit.fire(
                    pixel,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .recovered(let duration, let failureCount):
                let pixel: NetworkProtectionPixelEvent = {
                    switch duration {
                    case .immediate:
                        return .networkProtectionConnectionTesterFailureRecovered(server: server, failureCount: failureCount)
                    case .extended:
                        return .networkProtectionConnectionTesterExtendedFailureRecovered(server: server, failureCount: failureCount)
                    }
                }()

                PixelKit.fire(
                    pixel,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .reportConnectionAttempt(attempt: let attempt):
            vpnLogger.log(attempt)

            switch attempt {
            case .connecting:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionEnableAttemptConnecting,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionEnableAttemptSuccess,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failure:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionEnableAttemptFailure,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .reportTunnelFailure(result: let result):
            vpnLogger.log(result)

            switch result {
            case .failureDetected:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelFailureDetected,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failureRecovered:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelFailureRecovered,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .networkPathChanged:
                break
            }
        case .reportLatency(let result):
            vpnLogger.log(result)

            switch result {
            case .error:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionLatencyError,
                    frequency: .legacyDaily,
                    includeAppVersionParameter: true)
            case .quality(let quality):
                guard quality != .unknown else { return }
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionLatency(quality: quality),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .rekeyAttempt(let step):
            vpnLogger.log(step, named: "Rekey")

            switch step {
            case .begin:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionRekeyAttempt,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionRekeyFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionRekeyCompleted,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .tunnelStartAttempt(let step):
            vpnLogger.log(step, named: "Tunnel Start")

            switch step {
            case .begin:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStartAttempt,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStartFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStartSuccess,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .tunnelStopAttempt(let step):
            vpnLogger.log(step, named: "Tunnel Stop")

            switch step {
            case .begin:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStopAttempt,
                    frequency: .standard,
                    includeAppVersionParameter: true)
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStopFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelStopSuccess,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .tunnelUpdateAttempt(let step):
            vpnLogger.log(step, named: "Tunnel Update")

            switch step {
            case .begin:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelUpdateAttempt,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelUpdateFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelUpdateSuccess,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .tunnelWakeAttempt(let step):
            vpnLogger.log(step, named: "Tunnel Wake")

            switch step {
            case .begin, .success: break
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionTunnelWakeFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .failureRecoveryAttempt(let step):
            vpnLogger.log(step)

            switch step {
            case .started:
                PixelKit.fire(
                    VPNFailureRecoveryPixel.vpnFailureRecoveryStarted,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true
                )
            case .completed(.healthy):
                PixelKit.fire(
                    VPNFailureRecoveryPixel.vpnFailureRecoveryCompletedHealthy,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true
                )
            case .completed(.unhealthy):
                PixelKit.fire(
                    VPNFailureRecoveryPixel.vpnFailureRecoveryCompletedUnhealthy,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true
                )
            case .failed(let error):
                PixelKit.fire(
                    VPNFailureRecoveryPixel.vpnFailureRecoveryFailed(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true
                )
            }
        case .serverMigrationAttempt(let step):
            vpnLogger.log(step, named: "Server Migration")

            switch step {
            case .begin:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionServerMigrationAttempt,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .failure(let error):
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionServerMigrationFailure(error),
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            case .success:
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionServerMigrationSuccess,
                    frequency: .legacyDailyAndCount,
                    includeAppVersionParameter: true)
            }
        case .tunnelStartOnDemandWithoutAccessToken:
            vpnLogger.logStartingWithoutAuthToken()

            PixelKit.fire(
                NetworkProtectionPixelEvent.networkProtectionTunnelStartAttemptOnDemandWithoutAccessToken,
                frequency: .legacyDailyAndCount,
                includeAppVersionParameter: true)
        }
    }

    static var tokenServiceName: String {
#if NETP_SYSTEM_EXTENSION
        "\(Bundle.main.bundleIdentifier!).authToken"
#else
        NetworkProtectionKeychainTokenStore.Defaults.tokenStoreService
#endif
    }

    // MARK: - Initialization

    @MainActor @objc public init() {
        Logger.networkProtection.log("[+] MacPacketTunnelProvider")
#if NETP_SYSTEM_EXTENSION
        let defaults = UserDefaults.standard
#else
        let defaults = UserDefaults.netP
#endif

        APIRequest.Headers.setUserAgent(UserAgent.duckDuckGoUserAgent())
        NetworkProtectionLastVersionRunStore(userDefaults: defaults).lastExtensionVersionRun = AppVersion.shared.versionAndBuildNumber
        let settings = VPNSettings(defaults: defaults)

        // MARK: - Subscription configuration

        // Align Subscription environment to the VPN environment
        var subscriptionEnvironment = SubscriptionEnvironment.default
        switch settings.selectedEnvironment {
        case .production:
            subscriptionEnvironment.serviceEnvironment = .production
        case .staging:
            subscriptionEnvironment.serviceEnvironment = .staging
        }
        // The SysExt doesn't care about the purchase platform because the only operations executed here are about the Auth token. No purchase or
        // platforms-related operations are performed.
        subscriptionEnvironment.purchasePlatform = .stripe
        Logger.networkProtection.debug("Subscription ServiceEnvironment: \(subscriptionEnvironment.serviceEnvironment.rawValue, privacy: .public)")

        let subscriptionUserDefaults = UserDefaults(suiteName: MacPacketTunnelProvider.subscriptionsAppGroup)!
        let notificationCenter: NetworkProtectionNotificationCenter = DistributedNotificationCenter.default()
        let controllerErrorStore = NetworkProtectionTunnelErrorStore(notificationCenter: notificationCenter)
        let debugEvents = Self.networkProtectionDebugEvents(controllerErrorStore: controllerErrorStore)

        var tokenHandler: any SubscriptionTokenHandling
        var entitlementsCheck: (() async -> Result<Bool, Error>)

        if !PacketTunnelProvider.isAuthV2Enabled {
            // MARK: V1
            let tokenStore = NetworkProtectionKeychainTokenStore(keychainType: Bundle.keychainType,
                                                                               serviceName: Self.tokenServiceName,
                                                                               errorEvents: debugEvents,
                                                                               useAccessTokenProvider: false,
                                                                 accessTokenProvider: {
                assertionFailure("Should not be called")
                return nil
            })
            let entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: subscriptionUserDefaults,
                                                                     key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                                     settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))

            let subscriptionEndpointService = DefaultSubscriptionEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
            let authEndpointService = DefaultAuthEndpointService(currentServiceEnvironment: subscriptionEnvironment.serviceEnvironment)
            let accountManager = DefaultAccountManager(accessTokenStorage: tokenStore,
                                                       entitlementsCache: entitlementsCache,
                                                       subscriptionEndpointService: subscriptionEndpointService,
                                                       authEndpointService: authEndpointService)

            entitlementsCheck = {
                Logger.networkProtection.log("Subscription Entitlements check...")
                return await accountManager.hasEntitlement(forProductName: .networkProtection, cachePolicy: .reloadIgnoringLocalCacheData)
            }

            self.accountManager = accountManager
            tokenHandler = accountManager
        } else {
            // MARK: V2
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let urlSession = URLSession(configuration: configuration, delegate: SessionDelegate(), delegateQueue: nil)
            let apiService = DefaultAPIService(urlSession: urlSession)
            let authService = DefaultOAuthService(baseURL: subscriptionEnvironment.authEnvironment.url, apiService: apiService)
            let tokenStorage = NetworkProtectionKeychainStore(label: "DuckDuckGo Network Protection Auth Token",
                                                              serviceName: Self.tokenServiceName,
                                                              keychainType: Bundle.keychainType)
            let legacyTokenStore = NetworkProtectionKeychainTokenStore(keychainType: Bundle.keychainType,
                                                                               serviceName: Self.tokenServiceName,
                                                                               errorEvents: debugEvents,
                                                                               useAccessTokenProvider: false,
                                                                               accessTokenProvider: { nil })
            let authClient = DefaultOAuthClient(tokensStorage: tokenStorage,
                                                legacyTokenStorage: legacyTokenStore,
                                                authService: authService)
            apiService.authorizationRefresherCallback = { _ in
                guard let tokenContainer = tokenStorage.tokenContainer else {
                    throw OAuthClientError.internalError("Missing refresh token")
                }
                if tokenContainer.decodedAccessToken.isExpired() {
                    Logger.networkProtection.debug("Refreshing tokens")
                    let tokens = try await authClient.getTokens(policy: .localForceRefresh)
                    return VPNAuthTokenBuilder.getVPNAuthToken(from: tokens.accessToken)
                } else {
                    Logger.networkProtection.error("Trying to refresh valid token, using the old one")
                    return VPNAuthTokenBuilder.getVPNAuthToken(from: tokenContainer.accessToken)
                }
            }

            let subscriptionEndpointService = DefaultSubscriptionEndpointServiceV2(apiService: apiService,
                                                                                   baseURL: subscriptionEnvironment.serviceEnvironment.url)
            let pixelHandler: SubscriptionManagerV2.PixelHandler = { type in
                // The SysExt handles only dead token pixels
                switch type {
                case .deadToken:
                    PixelKit.fire(PrivacyProPixel.privacyProDeadTokenDetected)
                case .subscriptionIsActive: // handled by the main app only
                    break
                case .v1MigrationFailed:
                    PixelKit.fire(PrivacyProPixel.authV1MigrationFailed)
                case .v1MigrationSuccessful:
                    PixelKit.fire(PrivacyProPixel.authV1MigrationSucceeded)
                }
            }

            let subscriptionManager = DefaultSubscriptionManagerV2(oAuthClient: authClient,
                                                                 subscriptionEndpointService: subscriptionEndpointService,
                                                                 subscriptionEnvironment: subscriptionEnvironment,
                                                                   pixelHandler: pixelHandler,
                                                                   autoRecoveryHandler: {
                // todo Implement
            },
                                                                   initForPurchase: false)

            entitlementsCheck = {
                Logger.networkProtection.log("Subscription Entitlements check...")
                let isNetworkProtectionEnabled = await subscriptionManager.isFeatureAvailableForUser(.networkProtection)
                Logger.networkProtection.log("Network protection is \( isNetworkProtectionEnabled ? "🟢 Enabled" : "⚫️ Disabled", privacy: .public)")
                return .success(isNetworkProtectionEnabled)
            }

            // Subscription initial tasks
            Task {
                await subscriptionManager.loadInitialData()
            }

            self.accountManager = nil
            tokenHandler = subscriptionManager
        }

        // MARK: -

        let tunnelHealthStore = NetworkProtectionTunnelHealthStore(notificationCenter: notificationCenter)
        let notificationsPresenter = NetworkProtectionNotificationsPresenterFactory().make(settings: settings, defaults: defaults)

        super.init(notificationsPresenter: notificationsPresenter,
                   tunnelHealthStore: tunnelHealthStore,
                   controllerErrorStore: controllerErrorStore,
                   snoozeTimingStore: NetworkProtectionSnoozeTimingStore(userDefaults: .netP),
                   wireGuardInterface: DefaultWireGuardInterface(),
                   keychainType: Bundle.keychainType,
                   tokenHandler: tokenHandler,
                   debugEvents: debugEvents,
                   providerEvents: Self.packetTunnelProviderEvents,
                   settings: settings,
                   defaults: defaults,
                   entitlementCheck: entitlementsCheck)

        setupPixels()
        accountManager?.delegate = self
        observeServerChanges()
        observeStatusUpdateRequests()
        Logger.networkProtection.log("[+] MacPacketTunnelProvider Initialised")
    }

    deinit {
        Logger.networkProtectionMemory.log("[-] MacPacketTunnelProvider")
    }

    // MARK: - Observing Changes & Requests

    /// Observe connection status changes to broadcast those changes through distributed notifications.
    ///
    public override func handleConnectionStatusChange(old: ConnectionStatus, new: ConnectionStatus) {
        super.handleConnectionStatusChange(old: old, new: new)

        lastStatusChangeDate = Date()
        broadcast(new)
    }

    /// Observe server changes to broadcast those changes through distributed notifications.
    ///
    @MainActor
    private func observeServerChanges() {
        lastSelectedServerInfoPublisher.sink { [weak self] server in
            self?.lastStatusChangeDate = Date()
            self?.broadcast(server)
        }
        .store(in: &cancellables)

        broadcastLastSelectedServerInfo()
    }

    /// Observe status update requests to broadcast connection status
    ///
    private func observeStatusUpdateRequests() {
        notificationCenter.publisher(for: .requestStatusUpdate).sink { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                self.broadcastConnectionStatus()
                self.broadcastLastSelectedServerInfo()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Broadcasting Status and Information

    /// Broadcasts the current connection status.
    ///
    @MainActor
    private func broadcastConnectionStatus() {
        broadcast(connectionStatus)
    }

    /// Broadcasts the specified connection status.
    ///
    private func broadcast(_ connectionStatus: ConnectionStatus) {
        let lastStatusChange = ConnectionStatusChange(status: connectionStatus, on: lastStatusChangeDate)
        let payload = ConnectionStatusChangeEncoder().encode(lastStatusChange)

        notificationCenter.post(.statusDidChange, object: payload)
    }

    /// Broadcasts the current server information.
    ///
    @MainActor
    private func broadcastLastSelectedServerInfo() {
        broadcast(lastSelectedServerInfo)
    }

    /// Broadcasts the specified server information.
    ///
    private func broadcast(_ serverInfo: NetworkProtectionServerInfo?) {
        guard let serverInfo else {
            return
        }

        let serverStatusInfo = NetworkProtectionStatusServerInfo(
            serverLocation: serverInfo.attributes,
            serverAddress: serverInfo.endpoint?.host.hostWithoutPort
        )
        let payload = ServerSelectedNotificationObjectEncoder().encode(serverStatusInfo)

        notificationCenter.post(.serverSelected, object: payload)
    }

    // MARK: - NEPacketTunnelProvider

    public override func load(options: StartupOptions) async throws {
        try await super.load(options: options)

#if NETP_SYSTEM_EXTENSION
        loadExcludeLocalNetworks(from: options)
#endif
    }

    private func loadExcludeLocalNetworks(from options: StartupOptions) {
        switch options.excludeLocalNetworks {
        case .set(let exclude):
            settings.excludeLocalNetworks = exclude
        case .useExisting:
            break
        case .reset:
            settings.excludeLocalNetworks = true
        }
    }

    enum ConfigurationError: Error {
        case missingProviderConfiguration
        case missingPixelHeaders
    }

    public override func loadVendorOptions(from provider: NETunnelProviderProtocol?) throws {
        try super.loadVendorOptions(from: provider)

        guard let vendorOptions = provider?.providerConfiguration else {
            Logger.networkProtection.log("🔵 Provider is nil, or providerConfiguration is not set")
            throw ConfigurationError.missingProviderConfiguration
        }

        try loadDefaultPixelHeaders(from: vendorOptions)
    }

    private func loadDefaultPixelHeaders(from options: [String: Any]) throws {
        guard let defaultPixelHeaders = options[NetworkProtectionOptionKey.defaultPixelHeaders] as? [String: String] else {
            Logger.networkProtection.log("🔵 Pixel options are not set")
            throw ConfigurationError.missingPixelHeaders
        }

        setupPixels(defaultHeaders: defaultPixelHeaders)
    }

    // MARK: - Overrideable Connection Events

    override func prepareToConnect(using provider: NETunnelProviderProtocol?) {
        Logger.networkProtection.log("Preparing to connect...")
        super.prepareToConnect(using: provider)
        guard PixelKit.shared == nil, let options = provider?.providerConfiguration else { return }
        try? loadDefaultPixelHeaders(from: options)
    }

    // MARK: - Pixels

    private func setupPixels(defaultHeaders: [String: String] = [:]) {
        let dryRun: Bool
#if DEBUG
        dryRun = true
#else
        dryRun = false
#endif

        let source: String

#if NETP_SYSTEM_EXTENSION
        source = "vpnSystemExtension"
#else
        source = "vpnAppExtension"
#endif

        PixelKit.setUp(dryRun: dryRun,
                       appVersion: AppVersion.shared.versionNumber,
                       source: source,
                       defaultHeaders: defaultHeaders,
                       defaults: .netP) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping PixelKit.CompletionBlock) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers)
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error == nil, error)
            }
        }
    }

}

final class DefaultWireGuardInterface: WireGuardInterface {
    func turnOn(settings: UnsafePointer<CChar>, handle: Int32) -> Int32 {
        wgTurnOn(settings, handle)
    }

    func turnOff(handle: Int32) {
        wgTurnOff(handle)
    }

    func getConfig(handle: Int32) -> UnsafeMutablePointer<CChar>? {
        return wgGetConfig(handle)
    }

    func setConfig(handle: Int32, config: String) -> Int64 {
        return wgSetConfig(handle, config)
    }

    func bumpSockets(handle: Int32) {
        wgBumpSockets(handle)
    }

    func disableSomeRoamingForBrokenMobileSemantics(handle: Int32) {
        wgDisableSomeRoamingForBrokenMobileSemantics(handle)
    }

    func setLogger(context: UnsafeMutableRawPointer?, logFunction: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?) -> Void)?) {
        wgSetLogger(context, logFunction)
    }
}

extension MacPacketTunnelProvider: AccountManagerKeychainAccessDelegate {

    public func accountManagerKeychainAccessFailed(accessType: AccountKeychainAccessType, error: AccountKeychainAccessError) {
        PixelKit.fire(PrivacyProErrorPixel.privacyProKeychainAccessError(accessType: accessType, accessError: error),
                      frequency: .legacyDailyAndCount)
    }
}
