//
//  SubscriptionManagerMock.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
@testable import Subscription

public final class SubscriptionManagerMock: SubscriptionManager {
    public var email: String?

    public var isEligibleForFreeTrialResult: Bool = false

    public var accountManager: AccountManager
    public var subscriptionEndpointService: SubscriptionEndpointService
    public var authEndpointService: AuthEndpointService
    public var subscriptionFeatureMappingCache: SubscriptionFeatureMappingCache

    public static var storedEnvironment: SubscriptionEnvironment?
    public static func loadEnvironmentFrom(userDefaults: UserDefaults) -> SubscriptionEnvironment? {
        return storedEnvironment
    }

    public static func save(subscriptionEnvironment: SubscriptionEnvironment, userDefaults: UserDefaults) {
        storedEnvironment = subscriptionEnvironment
    }

    public var currentEnvironment: SubscriptionEnvironment
    public var canPurchase: Bool

    public func storePurchaseManager() -> StorePurchaseManager {
        internalStorePurchaseManager
    }

    public func loadInitialData() async {

    }

    public func refreshCachedSubscriptionAndEntitlements(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    public func url(for type: SubscriptionURL) -> URL {
        type.subscriptionURL(environment: currentEnvironment.serviceEnvironment)
    }

    public var urlForPurchaseFromRedirect: URL!
    public func urlForPurchaseFromRedirect(redirectURLComponents: URLComponents, tld: Common.TLD) -> URL {
        urlForPurchaseFromRedirect
    }

    public func currentSubscriptionFeatures() async -> [Entitlement.ProductName] {
        return []
    }

    public init(accountManager: AccountManager,
                subscriptionEndpointService: SubscriptionEndpointService,
                authEndpointService: AuthEndpointService,
                storePurchaseManager: StorePurchaseManager,
                currentEnvironment: SubscriptionEnvironment,
                canPurchase: Bool,
                subscriptionFeatureMappingCache: SubscriptionFeatureMappingCache) {
        self.accountManager = accountManager
        self.subscriptionEndpointService = subscriptionEndpointService
        self.authEndpointService = authEndpointService
        self.internalStorePurchaseManager = storePurchaseManager
        self.currentEnvironment = currentEnvironment
        self.canPurchase = canPurchase
        self.subscriptionFeatureMappingCache = subscriptionFeatureMappingCache
    }

    // MARK: -

    let internalStorePurchaseManager: StorePurchaseManager

    public func getToken() async throws -> String {
        guard let accessToken = accountManager.accessToken else {
            throw SubscriptionManagerError.tokenUnavailable(error: nil)
        }
        return accessToken
    }

    public func removeToken() async throws {
        assertionFailure("Unsupported")
    }

    public func getAccessToken() async throws -> String {
        try await getToken()
    }

    public func removeAccessToken() {
        try? accountManager.removeAccessToken()
    }

    public func refreshToken() async throws {
        assertionFailure("Unsupported")
    }

    public func adoptToken(_ someKindOfToken: Any) async throws {
        assertionFailure("Unsupported")
    }

    public var isUserAuthenticated: Bool {
        accountManager.isUserAuthenticated
    }

    public func isFeatureEnabledForUser(feature: Subscription.Entitlement.ProductName) async -> Bool {
        guard let hasEntitlement = try? await isFeatureAvailableAndEnabled(feature: feature, cachePolicy: .returnCacheDataElseLoad) else {
            return false
        }
        return hasEntitlement
    }

    public func isFeatureAvailableAndEnabled(feature: Entitlement.ProductName, cachePolicy: APICachePolicy) async throws -> Bool {

        let result = await accountManager.hasEntitlement(forProductName: .networkProtection, cachePolicy: cachePolicy)
        switch result {
        case .success(let hasEntitlements):
            return hasEntitlements
        case .failure(let error):
            throw error
        }
    }

    public func signOut(notifyUI: Bool) async {
        accountManager.signOut(skipNotification: !notifyUI)
    }

    public func getSubscription(cachePolicy: SubscriptionCachePolicy) async throws -> PrivacyProSubscription {
        if let accessToken = accountManager.accessToken {
            let subscriptionResult = await subscriptionEndpointService.getSubscription(accessToken: accessToken, cachePolicy: cachePolicy.apiCachePolicy)
            if case let .success(subscription) = subscriptionResult {
                return subscription
            } else {
                throw SubscriptionEndpointServiceError.noData
            }
        } else {
            throw SubscriptionEndpointServiceError.noData
        }
    }

    public func isSubscriptionPresent() -> Bool {
        isUserAuthenticated
    }

    public func isUserEligibleForFreeTrial() -> Bool {
        isEligibleForFreeTrialResult
    }
}
