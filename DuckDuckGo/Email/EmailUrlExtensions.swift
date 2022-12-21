//
//  EmailUrlExtensions.swift
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
import BrowserServicesKit

extension EmailUrls {

    private struct Url {
        static let emailProtectionLink = "https://duckduckgo.com/email"
    }

    private struct DevUrl {
        static let emailProtectionLink = "https://quackdev.duckduckgo.com/email"
    }

    var emailProtectionLink: URL {
        #if DEBUG
        return URL(string: DevUrl.emailProtectionLink)!
        #else
        return URL(string: Url.emailProtectionLink)!
        #endif
    }

    func isDuckDuckGoEmailProtection(url: URL) -> Bool {
        return url.absoluteString.starts(with: Url.emailProtectionLink)
    }

}
