//
//  CheckDefaultBrowserServiceTests.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Testing
import class UIKit.UIApplication
@testable import DuckDuckGo
import Foundation

struct CheckDefaultBrowserServiceTests {
    private static let isLowerThanIOS18PointTwo: Bool = {
        if #available(iOS 18.2, *) {
            true
        } else {
            false
        }
    }()

    @MainActor
    @Test(
        "Check Is Default Browser returns success when there are no errors",
        arguments: [
            true,
            false
        ]
    )
    @available(iOS 18.2, *)
    func checkDefaultBrowserReturnsSuccess(_ expectedDefaultBrowserValue: Bool) throws {
        // GIVEN
        let application = MockApplication()
        application.resultToReturn = .success(expectedDefaultBrowserValue)
        let sut = SystemCheckDefaultBrowserService(application: application)

        // WHEN
        let result = sut.isDefaultWebBrowser()

        // THEN
        #expect(try result.get() == expectedDefaultBrowserValue)
    }

    @MainActor
    @Test("Check is Default Browser returns maxNumberOfAttemptsExceeded when rateLimited error")
    @available(iOS 18.2, *)
    func checkDefaultBrowserReturnsMaxNumberOfAttemptsExceededFailure() throws {
        // GIVEN
        let timestamp: TimeInterval = 1773122108000 // 10th of March 2026
        let expectedRetryDate = Date(timeIntervalSince1970: timestamp)
        let systemError = NSError(
            domain: UIApplication.CategoryDefaultError.errorDomain,
            code: UIApplication.CategoryDefaultError.rateLimited.rawValue,
            userInfo: [
                UIApplication.CategoryDefaultError.retryAvailableDateErrorKey: expectedRetryDate,
            ]
        )
        let application = MockApplication()
        application.resultToReturn = .failure(systemError)
        let sut = SystemCheckDefaultBrowserService(application: application)

        // WHEN
        let result = sut.isDefaultWebBrowser()

        // THEN
        let error = try #require(try result.getError())
        guard case let CheckDefaultBrowserServiceError.maxNumberOfAttemptsExceeded(nextRetryDate) = error else {
            Issue.record("Should be maxNumberOfAttemptsExceeded error")
            return
        }
        #expect(nextRetryDate == expectedRetryDate)
    }

    @MainActor
    @Test("Check is Default Browser returns unknown failure when generic error")
    @available(iOS 18.2, *)
    func checkDefaultBrowserReturnsUnknownFailure() throws {
        // GIVEN
        let systemError = NSError(
            domain: UIApplication.CategoryDefaultError.errorDomain,
            code: 123456,
            userInfo: nil
        )
        let application = MockApplication()
        application.resultToReturn = .failure(systemError)
        let sut = SystemCheckDefaultBrowserService(application: application)

        // WHEN
        let result = sut.isDefaultWebBrowser()

        // THEN
        let error = try #require(try result.getError())
        guard case let CheckDefaultBrowserServiceError.unknownError(error) = error else {
            Issue.record("Should be maxNumberOfAttemptsExceeded error")
            return
        }
        #expect(error == systemError)
    }

    @Test(.disabled(if: CheckDefaultBrowserServiceTests.isLowerThanIOS18PointTwo))
    func legacyCheckDefaultBrowserReturnsNotSupportedFailure() throws {
        // GIVEN
        let sut = SystemCheckDefaultBrowserService()

        // WHEN
        let result = sut.isDefaultWebBrowser()

        // THEN
        let error = try #require(try result.getError())
        #expect(error == .notSupportedOnThisOSVersion)
    }

}

@available(iOS 18.2, *)
private class MockApplication: ApplicationDefaultCategoryChecking {
    var resultToReturn: Result<Bool, Error> = .success(false)

    func isDefault(_ category: UIApplication.Category) throws -> Bool {
        switch resultToReturn {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

private extension Result {

    func getError() throws -> Failure {
        switch self {
        case .success:
            throw NSError(domain: "testing expecting failure", code: 0, userInfo: nil)
        case let .failure(error):
            return error
        }
    }

}
