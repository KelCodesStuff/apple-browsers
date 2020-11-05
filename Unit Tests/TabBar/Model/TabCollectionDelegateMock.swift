//
//  File.swift
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
@testable import DuckDuckGo_Privacy_Browser

class TabCollectionDelegateMock: TabCollectionDelegate {

    var didAppendCalled = false

    func tabCollection(_ tabCollection: TabCollection, didAppend tab: Tab) {
        didAppendCalled = true
    }

    var didInsertCalled = false

    func tabCollection(_ tabCollection: TabCollection, didInsert tab: Tab, at index: Int) {
        didInsertCalled = true
    }

    var didRemoveCalled = false

    func tabCollection(_ tabCollection: TabCollection, didRemoveTabAt index: Int) {
        didRemoveCalled = true
    }

    var didRemoveAllAndAppendCalled = false

    func tabCollection(_ tabCollection: TabCollection, didRemoveAllAndAppend tab: Tab) {
        didRemoveAllAndAppendCalled = true
    }

    var didMoveCalled = false

    func tabCollection(_ tabCollection: TabCollection, didMoveTabAt index: Int, to newIndex: Int) {
        didMoveCalled = true
    }

}
