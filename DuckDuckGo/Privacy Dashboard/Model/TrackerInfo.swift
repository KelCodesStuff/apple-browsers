//
//  TrackerInfo.swift
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

import Foundation
import TrackerRadarKit
import BrowserServicesKit

struct TrackerInfo: Encodable {
    
    private(set) var trackers = Set<DetectedRequest>()
    private(set) var thirdPartyRequests = Set<DetectedRequest>()
    private(set) var installedSurrogates = Set<String>()

    mutating func add(detectedTracker: DetectedRequest) {
        trackers.insert(detectedTracker)
    }
    
    mutating func add(detectedThirdPartyRequest request: DetectedRequest) {
        thirdPartyRequests.insert(request)
    }

    mutating func add(installedSurrogateHost: String) {
        installedSurrogates.insert(installedSurrogateHost)
    }

    var isEmpty: Bool {
        return trackers.count == 0 &&
            thirdPartyRequests.count == 0 &&
            installedSurrogates.count == 0
    }
    
    var trackersBlocked: Set<DetectedRequest> {
        return trackers.filter { $0.isBlocked }
    }

}
