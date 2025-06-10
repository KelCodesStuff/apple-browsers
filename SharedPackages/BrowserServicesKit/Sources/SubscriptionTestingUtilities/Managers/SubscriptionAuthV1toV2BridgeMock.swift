//
//  SubscriptionAuthV1toV2BridgeMock.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

public final class SubscriptionAuthV1toV2BridgeMock: SubscriptionAuthV1toV2Bridge {

    public init() {}

    public var enabledFeatures: [Subscription.Entitlement.ProductName] = []
    public func isFeatureAvailableAndEnabled(feature: Subscription.Entitlement.ProductName, cachePolicy: Subscription.APICachePolicy) async throws -> Bool {
        enabledFeatures.contains(feature)
    }
    public func isFeatureEnabledForUser(feature: Subscription.Entitlement.ProductName) async -> Bool {
        enabledFeatures.contains(feature)
    }

    public var subscriptionFeatures: [Subscription.Entitlement.ProductName] = []
    public func currentSubscriptionFeatures() async -> [Subscription.Entitlement.ProductName] {
        subscriptionFeatures
    }

    public func signOut(notifyUI: Bool) async {
        accessTokenResult = .failure(SubscriptionManagerError.tokenUnavailable(error: nil))
    }

    public var canPurchase: Bool = true

    public var returnSubscription: Result<Subscription.PrivacyProSubscription, Error>!
    public func getSubscription(cachePolicy: Subscription.SubscriptionCachePolicy) async throws -> Subscription.PrivacyProSubscription {
        switch returnSubscription! {
        case .success(let subscription):
            return subscription
        case .failure(let error):
            throw error
        }
    }

    public var urls: [Subscription.SubscriptionURL: URL] = [:]
    public func url(for type: Subscription.SubscriptionURL) -> URL {
        urls[type]!
    }

    public var email: String?

    public var currentEnvironment: Subscription.SubscriptionEnvironment = .init(serviceEnvironment: .staging, purchasePlatform: .appStore)

    public var urlForPurchaseFromRedirectResult: URL!
    public func urlForPurchaseFromRedirect(redirectURLComponents: URLComponents, tld: Common.TLD) -> URL {
        urlForPurchaseFromRedirectResult
    }

    public var accessTokenResult: Result<String, Error> = .failure(SubscriptionManagerError.tokenUnavailable(error: nil))
    public func getAccessToken() async throws -> String {
        switch accessTokenResult {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    public func removeAccessToken() {
        accessTokenResult = .failure(SubscriptionManagerError.tokenUnavailable(error: nil))
    }

    public var isUserAuthenticated: Bool {
        switch accessTokenResult {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    public func isSubscriptionPresent() -> Bool {
        switch returnSubscription! {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}
