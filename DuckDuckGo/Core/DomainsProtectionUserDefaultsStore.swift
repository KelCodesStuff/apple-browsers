//
//  DomainsProtectionUserDefaultsStore.swift
//  DuckDuckGo
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

import Foundation

public class DomainsProtectionUserDefaultsStore: DomainsProtectionStore {

    private struct Keys {
        static let unprotectedDomains = "com.duckduckgo.contentblocker.unprotectedDomains"
    }

    private var userDefaults: UserDefaults? {
        return UserDefaults()
    }

    public private(set) var unprotectedDomains: Set<String> {
        get {
            guard let data = userDefaults?.data(forKey: Keys.unprotectedDomains) else { return Set<String>() }
            guard let unprotectedDomains = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSet.self, from: data) as? Set<String> else {
                return Set<String>()
            }
            return unprotectedDomains
        }
        set(newUnprotectedDomain) {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newUnprotectedDomain, requiringSecureCoding: false) else { return }
            userDefaults?.set(data, forKey: Keys.unprotectedDomains)
        }
    }

    public func disableProtection(forDomain domain: String) {
        var domains = unprotectedDomains
        domains.insert(domain)
        unprotectedDomains = domains
    }

    public func enableProtection(forDomain domain: String) {
        var domains = unprotectedDomains
        domains.remove(domain)
        unprotectedDomains = domains
    }
}
