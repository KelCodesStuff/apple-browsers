//
//  ChromiumFaviconsReaderTests.swift
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

import XCTest
import Foundation
@testable import DuckDuckGo_Privacy_Browser

class ChromiumFaviconsReaderTests: XCTestCase {

    func testReadingFavicons() {
        let faviconsReader = ChromiumFaviconsReader(chromiumDataDirectoryURL: resourceURL())
        let favicons = faviconsReader.readFavicons()

        guard case let .success(favicons) = favicons else {
            XCTFail("Failed to read favicons")
            return
        }

        XCTAssertEqual(favicons.count, 4)
    }

    private func resourceURL() -> URL {
        let bundle = Bundle(for: ChromiumBookmarksReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Chrome Data")
    }

}
