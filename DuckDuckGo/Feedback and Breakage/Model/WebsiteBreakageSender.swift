//
//  WebsiteBreakageSender.swift
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

import Foundation

final class WebsiteBreakageSender {

    func sendWebsiteBreakage(_ websiteBreakage: WebsiteBreakage) {
        let parameters: [String: String] = ["category": websiteBreakage.category?.rawValue ?? "",
                                            "siteUrl": websiteBreakage.siteUrlString,
                                            "upgradedHttps": websiteBreakage.upgradedHttps ? "true" : "false",
                                            "tds": websiteBreakage.tdsETag?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? "",
                                            "blockedTrackers": websiteBreakage.blockedTrackerDomains.joined(separator: ","),
                                            "surrogates": websiteBreakage.installedSurrogates.joined(separator: ","),
                                            "ampUrl": websiteBreakage.ampURL,
                                            "urlParametersRemoved": websiteBreakage.urlParametersRemoved ? "true" : "false",
                                            "os": websiteBreakage.osVersion,
                                            "manufacturer": "Apple"]

        Pixel.fire(.brokenSiteReport, withAdditionalParameters: parameters)
    }

}
