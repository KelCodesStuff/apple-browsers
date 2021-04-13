//
//  NSMenuItemExtension.swift
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

import Cocoa

extension NSMenuItem {

    convenience init(title string: String, action selector: Selector?, target: AnyObject?, keyEquivalent charCode: String) {
        self.init(title: string, action: selector, keyEquivalent: charCode)
        self.target = target
    }

    convenience init(action selector: Selector?) {
        self.init()
        self.action = selector
    }

    var topMenu: NSMenu? {
        var menuItem = self
        while let parent = menuItem.parent {
            menuItem = parent
        }

        return menuItem.menu
    }

}
