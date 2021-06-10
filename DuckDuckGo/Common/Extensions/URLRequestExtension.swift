//
//  URLRequestExtension.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

extension URLRequest {

    enum HeaderKey: String {
        case acceptEncoding = "Accept-Encoding"
        case acceptLanguage = "Accept-Language"
        case userAgent = "User-Agent"
    }

    // Note: Change the user agent to macOS version before the release
    static func defaultRequest(with url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("gzip;q=1.0, compress;q=0.5",
                         forHTTPHeaderField: HeaderKey.acceptEncoding.rawValue)
        // Rewrite with an user agent created specifically for the macOS desktop browser
        // https://app.asana.com/0/0/1200259209069307/f
        request.setValue("ddg_ios/7.54.0.0 (com.duckduckgo.mobile.ios; iOS 14.0)",
                         forHTTPHeaderField: HeaderKey.userAgent.rawValue)

        let languages = Locale.preferredLanguages.prefix(6)
        let acceptLanguage = languages.enumerated().map { index, language in
            let q = 1.0 - (Double(index) * 0.1)
            return "\(language);q=\(q)"
        }.joined(separator: ", ")

        request.setValue(acceptLanguage,
                         forHTTPHeaderField: HeaderKey.acceptLanguage.rawValue)
        return request
    }

}
