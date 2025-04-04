//
//  MockFeatureFlagger.swift
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

import BrowserServicesKit

public final class MockFeatureFlagger: FeatureFlagger {
    public var allActiveExperiments: BrowserServicesKit.Experiments = [:]

    private(set) var didCallResolveCohort: Bool = false

    public var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
    public var localOverrides: FeatureFlagLocalOverriding?

    var mockActiveExperiments: [String: ExperimentData] = [:]

    var featuresStub: [String: Bool] = [:]
    public func isFeatureOn<Flag: FeatureFlagDescribing>(for featureFlag: Flag, allowOverride: Bool) -> Bool {
        featuresStub[featureFlag.rawValue] ?? false
    }

    var resolveCohortStub: (any FeatureFlagCohortDescribing)?
    public func resolveCohort<Flag>(for featureFlag: Flag, allowOverride: Bool) -> (any BrowserServicesKit.FeatureFlagCohortDescribing)? where Flag: BrowserServicesKit.FeatureFlagDescribing {
        resolveCohortStub
    }
}

final class MockInternalUserStoring: InternalUserStoring {
    var isInternalUser: Bool = false
}
