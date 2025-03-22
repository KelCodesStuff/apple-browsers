//
//  CapturingFaviconImageCache.swift
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

import Common
@testable import DuckDuckGo_Privacy_Browser

@MainActor
final class CapturingFaviconImageCache: FaviconImageCaching {

    init() {}

    init(faviconStoring: any FaviconStoring) {}

    var loaded: Bool = false

    func load() async throws {
        loadCallsCount += 1
    }

    func insert(_ favicons: [Favicon]) {
        insertCalls.append(favicons)
    }

    func get(faviconUrl: URL) -> Favicon? {
        getFaviconWithURLCalls.append(faviconUrl)
        return getFaviconWithURL(faviconUrl)
    }

    func getFavicons(with urls: some Sequence<URL>) -> [Favicon]? {
        getFaviconsWithURLsCalls.append(Array(urls))
        return getFaviconsWithURLs(urls)
    }

    @MainActor
    func cleanOldExcept(fireproofDomains: FireproofDomains, bookmarkManager: any BookmarkManager, completion: @escaping @MainActor () -> Void) {
        cleanCallsCount += 1
        completion()
    }

    @MainActor
    func burnExcept(fireproofDomains: FireproofDomains, bookmarkManager: any BookmarkManager, savedLogins: Set<String>, completion: @escaping @MainActor () -> Void) {
        burnCallsCount += 1
        completion()
    }

    @MainActor
    func burnDomains(_ baseDomains: Set<String>, exceptBookmarks bookmarkManager: any BookmarkManager, exceptSavedLogins logins: Set<String>, exceptHistoryDomains history: Set<String>, tld: Common.TLD, completion: @escaping @MainActor () -> Void) {
        burnDomainsCallsCount += 1
        completion()
    }

    var loadCallsCount: Int = 0
    var insertCalls: [[Favicon]] = []
    var getFaviconWithURLCalls: [URL] = []
    var getFaviconsWithURLsCalls: [[URL]] = []

    var cleanCallsCount: Int = 0
    var burnCallsCount: Int = 0
    var burnDomainsCallsCount: Int = 0

    var getFaviconWithURL: (URL) -> Favicon? = { _ in nil }
    var getFaviconsWithURLs: (any Sequence<URL>) -> [Favicon]? = { _ in nil }
}
