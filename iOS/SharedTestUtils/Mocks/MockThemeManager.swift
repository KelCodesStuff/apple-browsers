//
//  MockThemeManager.swift
//  DuckDuckGo
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
import UIKit

@testable import DuckDuckGo

final class MockThemeManager: ThemeManaging {
    var properties = ExperimentalThemingProperties()
    var currentTheme: any Theme = DefaultTheme()
    var currentInterfaceStyle: UIUserInterfaceStyle = .light

    func updateColorScheme() { }
    func toggleExperimentalTheming() { }
    func setThemeStyle(_ style: DuckDuckGo.ThemeStyle) { }
    func updateUserInterfaceStyle(window: UIWindow?) { }
}

extension ExperimentalThemingProperties {
    init(isExperimentalThemingEnabled: Bool) {
        self.init(isExperimentalThemingEnabled: isExperimentalThemingEnabled, isRoundedCornersTreatmentEnabled: false)
    }

    init() {
        self.init(isExperimentalThemingEnabled: false, isRoundedCornersTreatmentEnabled: false)
    }
}
