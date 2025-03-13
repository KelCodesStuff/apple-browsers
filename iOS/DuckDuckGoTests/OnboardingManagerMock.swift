//
//  OnboardingManagerMock.swift
//  DuckDuckGo
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
import Core
@testable import DuckDuckGo

final class OnboardingManagerMock: OnboardingAddToDockManaging, OnboardingSetAsDefaultExperimentManaging, OnboardingSettingsURLProvider {
    private(set) var didCallSettingsURLPath = false

    var isEnrolledInSetAsDefaultBrowserExperiment: Bool = false

    var settingsURLPathToReturn: String = "www.example.com"
    var settingsURLPath: String {
        get {
            didCallSettingsURLPath = true
            return settingsURLPathToReturn
        }
        set {
            settingsURLPathToReturn = newValue
        }
    }

    var addToDockEnabledState: OnboardingAddToDockState = .disabled

    func resolveSetAsDefaultBrowserExperimentCohort() -> OnboardingSetAsDefaultBrowserCohort? {
        nil
    }
}
