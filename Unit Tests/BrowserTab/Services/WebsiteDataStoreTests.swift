//
//  WebsiteDataStoreTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class WebCacheManagerTests: XCTestCase {

    func testWhenCookiesHaveSubDomainsOnSubDomainsAndWildcardsThenOnlyMatchingCookiesRetained() {
        let logins = MockPreservedLogins(domains: [
            "mobile.twitter.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "twitter.com"),
            .make(domain: ".twitter.com"),
            .make(domain: "mobile.twitter.com"),
            .make(domain: "fake.mobile.twitter.com"),
            .make(domain: ".fake.mobile.twitter.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "twitter.com"),
            MockDataRecord(recordName: "mobile.twitter.com"),
            MockDataRecord(recordName: "fake.mobile.twitter.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 15.0)

        XCTAssertEqual(cookieStore.cookies.count, 2)
        XCTAssertEqual(cookieStore.cookies[0].domain, ".twitter.com")
        XCTAssertEqual(cookieStore.cookies[1].domain, "mobile.twitter.com")
    }

    func testWhenClearedThenCookiesWithParentDomainsAreRetained() {

        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: ".example.com"),
            .make(domain: "facebook.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 30.0)

        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, ".example.com")

    }

    func testWhenClearedThenDDGCookiesAreRetained() {
        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "duckduckgo.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "duckduckgo.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 30.0)

        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, "duckduckgo.com")
    }

    func testWhenClearedThenCookiesForLoginsAreRetained() {
        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "www.example.com"),
            .make(domain: "facebook.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "www.example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 30.0)

        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, "www.example.com")

    }

    func testWhenClearIsCalledThenCompletionIsCalled() {
        let dataStore = MockDataStore()
        let logins = MockPreservedLogins(domains: [])

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.removeAllDataCalledCount, 1)
    }

    // MARK: Mocks

    class MockDataStore: WebsiteDataStore {

        var cookieStore: HTTPCookieStore?
        var records = [WKWebsiteDataRecord]()
        var removeAllDataCalledCount = 0

        func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping ([WKWebsiteDataRecord]) -> Void) {
            completionHandler(records)
        }

        func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping () -> Void) {
            removeAllDataCalledCount += 1

            // In the real implementation, records will be selectively removed or edited based on their Fireproof status. For simplicity in this test,
            // only remove records if all data types are removed, so that we can tell whether records for given domains still exist in some form.
            if dataTypes == WKWebsiteDataStore.allWebsiteDataTypes() {
                self.records = records.filter {
                    !dataRecords.contains($0) && dataTypes == $0.dataTypes
                }
            }

            completionHandler()
        }

    }

    class MockPreservedLogins: FireproofDomains {

        let domains: [String]

        override var fireproofDomains: [String] {
            return domains
        }

        init(domains: [String]) {
            self.domains = domains
        }

    }

    class MockDataRecord: WKWebsiteDataRecord {

        let recordName: String
        let recordTypes: Set<String>

        init(recordName: String, types: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes()) {
            self.recordName = recordName
            self.recordTypes = types
        }

        override var displayName: String {
            recordName
        }

        override var dataTypes: Set<String> {
            recordTypes
        }

    }

    class MockHTTPCookieStore: HTTPCookieStore {

        var cookies: [HTTPCookie]

        init(cookies: [HTTPCookie] = []) {
            self.cookies = cookies
        }

        func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void) {
            completionHandler(cookies)
        }

        func setCookie(_ cookie: HTTPCookie, completionHandler: (() -> Void)?) {
            cookies.append(cookie)
            completionHandler?()
        }

        func delete(_ cookie: HTTPCookie, completionHandler: (() -> Void)?) {
            cookies.removeAll { $0.domain == cookie.domain }
            completionHandler?()
        }

    }

}
