//
//  URL.swift
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
import os.log

extension URL {

    // MARK: - Factory

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var searchUrl = duckduckgo
            try searchUrl.addParameter(name: DuckduckgoParameters.search.rawValue, value: trimmedQuery)
            return searchUrl
        } catch let error {
            os_log("URL extension: %s", log: generalLog, type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        if let addressBarUrl = addressBarString.url {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: addressBarString) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", log: generalLog, type: .error, addressBarString)
        return nil
    }

    // MARK: - Parameters

    enum ParameterError: Error {
        case parsingFailed
        case creatingFailed
    }

    mutating func addParameter(name: String, value: String) throws {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        var queryItems = components.queryItems ?? [URLQueryItem]()
        let newQueryItem = URLQueryItem(name: name, value: value)
        queryItems.append(newQueryItem)
        components.queryItems = queryItems
        //todo? percent encoding?
        guard let newUrl = components.url else { throw ParameterError.creatingFailed }
        self = newUrl
    }

    func getParameter(name: String) throws -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        let queryItem = components.queryItems?.first(where: { (queryItem) -> Bool in
            queryItem.name == name
        })
        return queryItem?.value
    }

    // MARK: - Schemes

    enum Scheme: String, CaseIterable {
        case http
        case https

        func separated() -> String {
            self.rawValue + "://"
        }
    }

    // MARK: - DuckDuckGo

    static var duckduckgo: URL {
        let duckduckgoUrlString = "https://duckduckgo.com"
        return URL(string: duckduckgoUrlString)!
    }

    var isDuckDuckGo: Bool {
        absoluteString.starts(with: Self.duckduckgo.absoluteString)
    }

    enum DuckduckgoParameters: String {
        case search = "q"
    }

    // MARK: - Search

    var searchQuery: String? {
        guard isDuckDuckGo else { return nil }
        return try? getParameter(name: DuckduckgoParameters.search.rawValue)
    }

}
