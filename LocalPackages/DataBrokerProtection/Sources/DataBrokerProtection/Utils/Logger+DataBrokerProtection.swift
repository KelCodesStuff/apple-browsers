//
//  Logger+DataBrokerProtection.swift
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
import os.log

public extension Logger {
    fileprivate static let subsystem = "com.duckduckgo.macos.browser.databroker-protection"

    static var dataBrokerProtection = { Logger(subsystem: subsystem, category: "") }()
    static var action = { Logger(subsystem: subsystem, category: "Action") }()
    static var service = { Logger(subsystem: subsystem, category: "Service") }()
    static var backgroundAgent = { Logger(subsystem: subsystem, category: "Background Agent") }()
    static var backgroundAgentMemoryManagement = { Logger(subsystem: subsystem, category: "Background Agent Memory Management") }()
    static var pixel = { Logger(subsystem: subsystem, category: "Pixel") }()
}
