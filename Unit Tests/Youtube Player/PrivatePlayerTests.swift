//
//  PrivatePlayerTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import Combine
@testable import DuckDuckGo_Privacy_Browser

class MockPrivacyConfiguration: PrivacyConfiguration {
    var identifier: String = "MockPrivacyConfiguration"
    var userUnprotectedDomains: [String] = []
    var tempUnprotectedDomains: [String] = []
    var trackerAllowlist: PrivacyConfigurationData.TrackerAllowlistData = [:]

    func exceptionsList(forFeature featureKey: PrivacyFeature) -> [String] { [] }
    func isEnabled(featureKey: PrivacyFeature, versionProvider: AppVersionProvider) -> Bool { true }
    func isFeature(_ feature: PrivacyFeature, enabledForDomain: String?) -> Bool { true }
    func isProtected(domain: String?) -> Bool { true }
    func isUserUnprotected(domain: String?) -> Bool { false }
    func isTempUnprotected(domain: String?) -> Bool { false }
    func isInExceptionList(domain: String?, forFeature featureKey: PrivacyFeature) -> Bool { false }
    func settings(for feature: PrivacyFeature) -> PrivacyConfigurationData.PrivacyFeature.FeatureSettings { [:] }
    func userEnabledProtection(forDomain: String) {}
    func userDisabledProtection(forDomain: String) {}
}

@objc(MockPrivacyConfigurationManager)
class MockPrivacyConfigurationManager: NSObject, PrivacyConfigurationManaging {
    var embeddedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData {
        fatalError("not implemented")
    }

    var fetchedConfigData: BrowserServicesKit.PrivacyConfigurationManager.ConfigurationData? {
        fatalError("not implemented")
    }

    var currentConfig: Data {
        Data()
    }

    func reload(etag: String?, data: Data?) -> BrowserServicesKit.PrivacyConfigurationManager.ReloadResult {
        fatalError("not implemented")
    }

    var updatesPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()
    var privacyConfig: PrivacyConfiguration = MockPrivacyConfiguration()
}

final class PrivatePlayerTests: XCTestCase {

    var privatePlayer: PrivatePlayer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        privatePlayer = PrivatePlayer(
            preferences: .init(persistor: PrivatePlayerPreferencesPersistorMock()),
            privacyConfigurationManager: MockPrivacyConfigurationManager()
        )
    }

    func testThatImageForFaviconViewReturnsHardcodedFaviconForDuckPlayer() {
        let privatePlayerFaviconView = FaviconView(domain: PrivatePlayer.commonName)
        let otherFaviconView = FaviconView(domain: "example.com")

        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.image(for: privatePlayerFaviconView), NSImage.privatePlayer)
        XCTAssertNil(privatePlayer.image(for: otherFaviconView))

        privatePlayer.mode = .alwaysAsk
        XCTAssertEqual(privatePlayer.image(for: privatePlayerFaviconView), NSImage.privatePlayer)
        XCTAssertNil(privatePlayer.image(for: otherFaviconView))

        privatePlayer.mode = .disabled
        XCTAssertNil(privatePlayer.image(for: privatePlayerFaviconView))
        XCTAssertNil(privatePlayer.image(for: otherFaviconView))
    }

    func testThatDomainForRecentlyVisitedSiteIsReturnedForPrivatePlayerURLs() {
        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.domainForRecentlyVisitedSite(with: privatePlayerURL()), PrivatePlayer.commonName)
        XCTAssertNil(privatePlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))

        privatePlayer.mode = .alwaysAsk
        XCTAssertEqual(privatePlayer.domainForRecentlyVisitedSite(with: privatePlayerURL()), PrivatePlayer.commonName)
        XCTAssertNil(privatePlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))

        privatePlayer.mode = .disabled
        XCTAssertEqual(privatePlayer.domainForRecentlyVisitedSite(with: privatePlayerURL()), nil)
        XCTAssertNil(privatePlayer.domainForRecentlyVisitedSite(with: "https://duck.com".url!))
    }

    func testThatTabContentReturnsNilIfDisabled() {
        privatePlayer.mode = .disabled
        XCTAssertNil(privatePlayer.tabContent(for: .privatePlayer("12345678")))

        privatePlayer.mode = .alwaysAsk
        XCTAssertEqual(privatePlayer.tabContent(for: .privatePlayer("12345678")), .privatePlayer(videoID: "12345678", timestamp: nil))

        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.tabContent(for: .privatePlayer("12345678")), .privatePlayer(videoID: "12345678", timestamp: nil))
    }

    func testThatTabContentContainsTimestampIfTimestampIsInTheURL() {
        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.tabContent(for: .privatePlayer("12345678", timestamp: "10m")), .privatePlayer(videoID: "12345678", timestamp: "10m"))
    }

    func testThatTabContentReturnsPrivatePlayerURLForYoutubeNocookieURL() {
        privatePlayer.mode = .alwaysAsk
        XCTAssertEqual(privatePlayer.tabContent(for: .youtubeNoCookie("12345678", timestamp: "10m")), .privatePlayer(videoID: "12345678", timestamp: "10m"))
    }

    func testThatTabContentReturnsPrivatePlayerURLForYoutubeVideoURLOnlyInEnabledState() {
        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.tabContent(for: .youtube("12345678", timestamp: "10m")), .privatePlayer(videoID: "12345678", timestamp: "10m"))

        privatePlayer.mode = .alwaysAsk
        XCTAssertNil(privatePlayer.tabContent(for: .youtube("12345678", timestamp: "10m")))
    }

    func testThatSharingDataStripsDuckPlayerPrefixFromTitleAndReturnsYoutubeURL() {
        let sharingData = privatePlayer.sharingData(for: "Duck Player - sample video", url: "duck://player/12345678?t=10".url!)
        XCTAssertEqual(sharingData?.title, "sample video")
        XCTAssertEqual(sharingData?.url, URL.youtube("12345678", timestamp: "10"))
    }

    func testThatSharingDataForNonPrivatePlayerURLReturnsNil() {
        XCTAssertNil(privatePlayer.sharingData(for: "Wikipedia", url: "https://wikipedia.org".url!))
    }

    func testThatTitleForRecentlyVisitedPageIsGeneratedForPrivatePlayerFeedItems() {
        let feedItem = HomePage.Models.RecentlyVisitedPageModel(
            actualTitle: "Duck Player - A sample video title",
            url: privatePlayerURL(),
            visited: Date()
        )

        privatePlayer.mode = .enabled
        XCTAssertEqual(privatePlayer.title(for: feedItem), "A sample video title")

        privatePlayer.mode = .disabled
        XCTAssertNil(privatePlayer.title(for: feedItem))
    }

    func testThatTitleForRecentlyVisitedPageIsNotAdjustedForNonPrivatePlayerFeedItems() {
        let feedItem = HomePage.Models.RecentlyVisitedPageModel(
            actualTitle: "Duck Player - A sample video title",
            url: "https://duck.com".url!,
            visited: Date()
        )

        privatePlayer.mode = .enabled
        XCTAssertNil(privatePlayer.title(for: feedItem))
    }

    private func privatePlayerURL() -> URL {
        if #available(macOS 12.0, *) {
            return .youtubeNoCookie("12345678")
        } else {
            return .privatePlayer("12345678")
        }
    }
}
