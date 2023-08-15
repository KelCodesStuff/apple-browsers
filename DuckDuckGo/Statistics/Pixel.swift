//
//  Pixel.swift
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
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
import Networking
import Common

final class Pixel {

    static private(set) var shared: Pixel?

    static func setUp(dryRun: Bool = false) {
        shared = Pixel(dryRun: dryRun)
    }

    static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool
    static var isNewUser: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        return firstLaunchDate >= oneWeekAgo
    }

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    private static let moreInfoHeader: HTTPHeaders = [APIRequest.HTTPHeaderField.moreInfo: "See " + URL.duckDuckGoMorePrivacyInfo.absoluteString]

    // Temporary for activation pixels
    static private var aMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: aMonthAgo)
    static var firstLaunchDate: Date

    func fire(pixelNamed pixelName: String,
              withAdditionalParameters params: [String: String]? = nil,
              allowedQueryReservedCharacters: CharacterSet? = nil,
              includeAppVersionParameter: Bool = true,
              withHeaders headers: APIRequest.Headers = APIRequest.Headers(additionalHeaders: moreInfoHeader),
              onComplete: @escaping (Error?) -> Void = {_ in }) {

        var newParams = params ?? [:]
        if includeAppVersionParameter {
            newParams[Parameters.appVersion] = AppVersion.shared.versionNumber
        }
        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        guard !dryRun else {
            let params = params?.filter { key, _ in !["appVersion", "test"].contains(key) } ?? [:]
            os_log(.debug, log: .pixel, "%@ %@", pixelName.replacingOccurrences(of: "_", with: "."), params)
            // simulate server response time for Dry Run mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete(nil)
            }
            return
        }

        let configuration = APIRequest.Configuration(url: URL.pixelUrl(forPixelNamed: pixelName),
                                                     queryParameters: newParams,
                                                     allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                                                     headers: headers)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { (_, error) in
            onComplete(error)
        }
    }

    static func fire(_ event: Pixel.Event,
                     withAdditionalParameters parameters: [String: String]? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {
        let newParams: [String: String]?
        switch (event.parameters, parameters) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = nil
        }

        Self.shared?.fire(pixelNamed: event.name,
                          withAdditionalParameters: newParams,
                          allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                          includeAppVersionParameter: includeAppVersionParameter,
                          onComplete: onComplete)
    }

}

public func pixelAssertionFailure(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line) {
    Pixel.fire(.debug(event: Pixel.Event.Debug.assertionFailure(message: message(), file: file, line: line)))
    Swift.assertionFailure(message(), file: file, line: line)
}

extension Pixel {

    static func fire(_ event: Pixel.Event,
                     limitToOnceADay: Bool,
                     withAdditionalParameters parameters: [String: String]? = nil,
                     allowedQueryReservedCharacters: CharacterSet? = nil,
                     includeAppVersionParameter: Bool = true,

                     onComplete: @escaping (Error?) -> Void = {_ in }) {
        if limitToOnceADay {
            let repetition = Event.Repetition(key: event.name)
            if repetition == .repetitive {
                // Pixel alredy fired today
                return
            }
        }

        fire(event, withAdditionalParameters: parameters,
             allowedQueryReservedCharacters: allowedQueryReservedCharacters,
             includeAppVersionParameter: includeAppVersionParameter,
             onComplete: onComplete)
    }

}
