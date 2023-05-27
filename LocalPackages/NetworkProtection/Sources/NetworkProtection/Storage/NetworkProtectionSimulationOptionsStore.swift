//
//  NetworkProtectionSimulationOption.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

public enum NetworkProtectionSimulationOption: Sendable {
    case controllerFailure
    case tunnelFailure
}

public class NetworkProtectionSimulationOptions {
    private var options: [NetworkProtectionSimulationOption: Bool] = [:]

    public init() {}

    public func setEnabled(_ enabled: Bool, option: NetworkProtectionSimulationOption) {
        options[option] = enabled
    }

    public func isEnabled(_ option: NetworkProtectionSimulationOption) -> Bool {
        options[option] ?? false
    }
}
