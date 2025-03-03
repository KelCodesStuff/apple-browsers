//
//  HistoryViewOnboardingDeciderTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class MockHistoryViewOnboardingViewSettingsPersistor: HistoryViewOnboardingViewSettingsPersisting {
    var didShowOnboardingView: Bool = false
}

final class HistoryViewOnboardingDeciderTests: XCTestCase {

    var decider: HistoryViewOnboardingDecider!
    var featureFlagger: MockFeatureFlagger!
    var settingsPersistor: HistoryViewOnboardingViewSettingsPersisting!
    var isNewUser: Bool = false

    override func setUp() async throws {
        featureFlagger = MockFeatureFlagger()
        settingsPersistor = MockHistoryViewOnboardingViewSettingsPersistor()
        decider = HistoryViewOnboardingDecider(featureFlagger: featureFlagger, settingsPersistor: settingsPersistor, isNewUser: { self.isNewUser })

        featureFlagger.isFeatureOn = true
    }

    func testWhenFeatureFlagIsDisabledThenOnboardingShouldNotBePresented() {
        featureFlagger.isFeatureOn = false
        XCTAssertFalse(decider.shouldPresentOnboarding)
    }

    func testWhenFeatureFlagIsEnabledThenOnboardingShouldNotBePresented() {
        featureFlagger.isFeatureOn = true
        XCTAssertTrue(decider.shouldPresentOnboarding)
    }

    func testWhenIsNewUserThenOnboardingShouldNotBePresented() {
        isNewUser = true
        XCTAssertFalse(decider.shouldPresentOnboarding)
    }

    func testWhenIsOldUserThenOnboardingShouldBePresented() {
        isNewUser = false
        XCTAssertTrue(decider.shouldPresentOnboarding)
    }

    func testWhenOnboardingWasShownThenOnboardingShouldNotBePresented() {
        settingsPersistor.didShowOnboardingView = true
        XCTAssertFalse(decider.shouldPresentOnboarding)
    }

    func testWhenOnboardingWasNotShownThenOnboardingShouldBePresented() {
        settingsPersistor.didShowOnboardingView = false
        XCTAssertTrue(decider.shouldPresentOnboarding)
    }
}
