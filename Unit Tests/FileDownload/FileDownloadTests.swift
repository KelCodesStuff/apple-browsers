//
//  FileDownloadTests.swift
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
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

class FileDownloadTests: XCTestCase {

    let requestWithFileName = URLRequest(url: URL(string: "https://www.example.com/file.html")!)
    let requestWithPath = URLRequest(url: URL(string: "https://www.example.com/")!)

    func testWhenFileNameUnknownThenUniqueNameAssignedWithExtension() {
        let download = FileDownload(request: requestWithPath, suggestedName: nil)
        XCTAssertTrue(download.bestFileName(fileType: "pdf").hasPrefix("example_com_"))
        XCTAssertTrue(download.bestFileName(fileType: "pdf").hasSuffix(".pdf"))
    }

    func testWhenFileNameAndFileTypeUnknownThenUniqueNameAssigned() {
        let download = FileDownload(request: requestWithPath, suggestedName: nil)
        XCTAssertTrue(download.bestFileName(fileType: nil).hasPrefix("example_com_"))
    }

    func testWhenFileTypeMatchesThenNoExtensionDuplicationOccurs() {
        let download = FileDownload(request: requestWithFileName, suggestedName: nil)
        XCTAssertEqual("file.html", download.bestFileName(fileType: "html"))
    }

    func testWhenFileTypeDoesNotMatchURLFileThenFileTypeUsedForExtension() {
        let download = FileDownload(request: requestWithFileName, suggestedName: nil)
        XCTAssertEqual("file.html.pdf", download.bestFileName(fileType: "pdf"))
    }

    func testWhenSuggestedNameNotPresentAndURLHasFileNameThenFileNameIsBest() {
        let download = FileDownload(request: requestWithFileName, suggestedName: nil)
        XCTAssertEqual("file.html", download.bestFileName(fileType: nil))
    }

    func testWhenSuggestedNamePresentThenSuggestedIsBest() {
        let download = FileDownload(request: requestWithFileName, suggestedName: "suggested.ext")
        XCTAssertEqual("suggested.ext", download.bestFileName(fileType: nil))
        XCTAssertEqual("suggested.ext", download.bestFileName(fileType: "pdf"))
    }

}
