//
//  CrashReport.swift
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
import MetricKit

protocol CrashReportPresenting {
    var content: String? { get }
}

protocol CrashReport: CrashReportPresenting {

    static var fileExtension: String { get }

    var url: URL { get }
    var contentData: Data? { get }

}

struct LegacyCrashReport: CrashReport {

    static let fileExtension = "crash"

    static let headerItemsToFilter = [
        "Anonymous UUID:",
        "Sleep/Wake UUID:"
    ]

    let url: URL

    var content: String? {
        try? String(contentsOf: url)
            .components(separatedBy: "\n")
            .filter({ line in
                for headerItemToFilter in Self.headerItemsToFilter where line.hasPrefix(headerItemToFilter) {
                    return false
                }
                return true
            })
            .joined(separator: "\n")
    }

    var contentData: Data? {
        content?.data(using: .utf8)
    }

}

struct JSONCrashReport: CrashReport {

    static let fileExtension = "ips"

    static let headerItemsToFilter = [
        "sleepWakeUUID",
        "deviceIdentifierForVendor",
        "rolloutId"
    ]

    let url: URL

    var content: String? {
        guard var fileContents = try? String(contentsOf: url) else {
            return nil
        }

        for itemToFilter in Self.headerItemsToFilter {
            let patternToReplace = "\"\(itemToFilter)\"\\s*:\\s*\"[^\"]*\""
            let redactedKeyValuePair = "\"\(itemToFilter)\":\"<removed>\""

            fileContents = fileContents.replacingOccurrences(of: patternToReplace,
                                                             with: redactedKeyValuePair,
                                                             options: .regularExpression)
        }

        return fileContents
    }

    var contentData: Data? {
        content?.data(using: .utf8)
    }

}

@available(macOS 12.0, *)
extension MXDiagnosticPayload: CrashReportPresenting {
    var content: String? {
        jsonRepresentation().utf8String()
    }
}
