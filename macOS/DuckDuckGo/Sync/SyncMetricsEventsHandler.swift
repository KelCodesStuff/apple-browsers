//
//  SyncMetricsEventsHandler.swift
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

import Common
import SyncDataProviders
import Foundation
import PixelKit

public class SyncMetricsEventsHandler: EventMapping<MetricsEvent> {

    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .overrideEmailProtectionSettings:
                PixelKit.fire(GeneralPixel.syncDuckAddressOverride)
            case .localTimestampResolutionTriggered(let feature):
                PixelKit.fire(GeneralPixel.syncLocalTimestampResolutionTriggered(feature))
            }
        }
    }

    override init(mapping: @escaping EventMapping<MetricsEvent>.Mapping) {
        fatalError("Use init()")
    }
}
