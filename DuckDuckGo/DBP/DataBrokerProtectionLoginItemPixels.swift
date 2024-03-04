//
//  DataBrokerProtectionLoginItemPixels.swift
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

struct DataBrokerProtectionLoginItemPixels {

    static func fire(pixel: Pixel.Event, frequency: DailyPixel.PixelFrequency) {

        DispatchQueue.main.async { // delegateTyped needs to be called in the main thread
            let isInternalUser = NSApp.delegateTyped.internalUserDecider.isInternalUser
            DailyPixel.fire(pixel: pixel,
                            frequency: frequency,
                            includeAppVersionParameter: true,
                            withAdditionalParameters: [
                                "isInternalUser": isInternalUser.description
                            ]
            )
        }
    }
}
