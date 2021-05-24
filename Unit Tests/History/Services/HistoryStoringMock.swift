//
//  HistoryStoringMock.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Combine

final class HistoryStoringMock: HistoryStoring {

    enum HistoryStoringMockError: Error {
        case defaultError
    }

    var cleanAndReloadHistoryCalled = false
    var cleanAndReloadHistoryExteptions = [HistoryEntry]()
    var cleanAndReloadHistoryResult: Result<History, Error>?
    func cleanAndReloadHistory(until date: Date, except exceptions: [HistoryEntry]) -> Future<History, Error> {
        cleanAndReloadHistoryCalled = true
        cleanAndReloadHistoryExteptions = exceptions
        return Future { [weak self] promise in
            guard let cleanAndReloadHistoryResult = self?.cleanAndReloadHistoryResult else {
                promise(.failure(HistoryStoringMockError.defaultError))
                return
            }

            promise(cleanAndReloadHistoryResult)
        }
    }

    var saveCalled = false
    func save(entry: HistoryEntry) -> Future<Void, Error> {
        saveCalled = true
        return Future { promise in
            promise(.success(()))
        }
    }

}
