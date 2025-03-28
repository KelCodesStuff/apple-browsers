//
//  CombineTestHelpers.swift
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

import XCTest
import Combine

/*
 Code based on snippet from https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
 */
public extension XCTestCase {
    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        waitForFinish: Bool = true,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T.Output {
        // This time, we use Swift's Result type to keep track
        // of the result of our Combine pipeline:
        var result: Result<T.Output, Error>?
        let expectation = self.expectation(description: "Awaiting publisher")
        expectation.assertForOverFulfill = false

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    break
                }

                expectation.fulfill()
            },
            receiveValue: { value in
                result = .success(value)
                if !waitForFinish {
                    expectation.fulfill()
                }
            }
        )

        // Just like before, we await the expectation that we
        // created at the top of our test, and once done, we
        // also cancel our cancellable to avoid getting any
        // unused variable warnings:
        await fulfillment(of: [expectation])
        cancellable.cancel()

        // Here we pass the original file and line number that
        // our utility was called at, to tell XCTest to report
        // any encountered errors at that original call site:
        let unwrappedResult = try XCTUnwrap(
            result,
            "Awaited publisher did not produce any output",
            file: file,
            line: line
        )

        return try unwrappedResult.get()
    }

    @discardableResult
    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line,
        toEmit value: T.Output
    ) async throws -> T.Output where T.Output: Equatable {
        try await waitForPublisher(
            publisher.first {
                value == $0
            },
            waitForFinish: false
        )
    }
}
