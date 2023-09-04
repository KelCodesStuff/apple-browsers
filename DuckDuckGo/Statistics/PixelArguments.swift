//
//  PixelArguments.swift
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
import AppKit

extension Pixel.Event {

    enum Repetition: String, CustomStringConvertible {
        var description: String { rawValue }

        case initial = "initial"
        case dailyFirst = "first-in-a-day"
        case repetitive = "repetitive"

        init(key: String, store: PixelDataStore = LocalPixelDataStore.shared, now: Date = Date(), update: Bool = true) {
            defer {
                if update {
                    store.set(now.daySinceReferenceDate, forKey: key)
                }
            }

            guard let lastUsedDay: Int = store.value(forKey: key) else {
                self = .initial
                return
            }
            if lastUsedDay == now.daySinceReferenceDate {
                self = .repetitive
                return
            }
            self = .dailyFirst
        }
    }

    enum AccessPoint: String, CustomStringConvertible {
        var description: String { rawValue }

        case button = "source-button"
        case mainMenu = "source-menu"
        case tabMenu = "source-tab-menu"
        case hotKey = "source-keyboard"
        case moreMenu = "source-more-menu"
        case newTab = "source-new-tab"

        init(sender: Any, default: AccessPoint, mainMenuCheck: (NSMenu?) -> Bool = { $0 is MainMenu }) {
            switch sender {
            case let menuItem as NSMenuItem:
                if mainMenuCheck(menuItem.topMenu) {
                    if let event = NSApp.currentEvent,
                       case .keyDown = event.type,
                       event.characters == menuItem.keyEquivalent {

                        self = .hotKey
                    } else {
                        self = .mainMenu
                    }
                } else {
                    self = `default`
                }

            case is NSButton:
                self = .button

            default:
                assertionFailure("AccessPoint: Unexpected type of sender: \(type(of: sender))")
                self = `default`
            }
        }

    }

    enum FormAutofillKind: String, CustomStringConvertible {
        var description: String { rawValue }

        case password
        case card
        case identity
    }

    enum DataImportAction: String, CustomStringConvertible {
        var description: String { rawValue }

        case importBookmarks = "bookmarks"
        case importLogins = "logins"
        case generic = "generic"
    }

    enum DataImportSource: String, CustomStringConvertible {
        var description: String { rawValue }

        case brave = "source-brave"
        case chrome = "source-chrome"
        case csv = "source-csv"
        case lastPass = "source-lastpass"
        case onePassword7 = "source-1password"
        case onePassword8 = "source-1password-8"
        case edge = "source-edge"
        case firefox = "source-firefox"
        case safari = "source-safari"
        case bookmarksHTML = "source-bookmarks-html"
    }

    public enum CompileRulesListType: String, CustomStringConvertible {

        public var description: String { rawValue }

        case tds = "tracker_data"
        case clickToLoad = "click_to_load"
        case blockingAttribution = "blocking_attribution"
        case attributed = "attributed"
        case unknown = "unknown"

    }

    enum FireButtonOption: String, CustomStringConvertible {
        var description: String { rawValue }

        case tab
        case window
        case allSites = "all-sites"
    }
}
