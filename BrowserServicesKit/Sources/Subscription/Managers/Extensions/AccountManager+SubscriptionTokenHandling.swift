//
//  AccountManager+SubscriptionTokenHandling.swift
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
import Networking
import os.log

extension DefaultAccountManager: SubscriptionTokenHandling {

    public func getToken() async throws -> String {
        guard let accessToken = accessToken else {
            throw SubscriptionManagerError.tokenUnavailable(error: nil)
        }
        return accessToken
    }

    public func removeToken() async throws {
        assertionFailure("Unsupported")
    }

    public func refreshToken() async throws {
        assertionFailure("Unsupported")
    }

    public func adoptToken(_ someKindOfToken: Any) async throws {
        assertionFailure("Unsupported")
    }
}
