//
//  SuggestionViewModel.swift
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

import Cocoa
import BrowserServicesKit

final class SuggestionViewModel {

    let suggestion: Suggestion
    let userStringValue: String

    init(suggestion: Suggestion, userStringValue: String) {
        self.suggestion = suggestion
        self.userStringValue = userStringValue
    }

    // MARK: - Attributed Strings

    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    static let tableRowViewStandardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .paragraphStyle: paragraphStyle
    ]

    static let tableRowViewBoldAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .paragraphStyle: paragraphStyle
    ]

    var tableCellViewAttributedString: NSAttributedString {
        var firstPart = ""
        var boldPart = string
        if string.hasPrefix(userStringValue) {
            firstPart = String(string.prefix(userStringValue.count))
            boldPart = String(string.dropFirst(userStringValue.count))
        }

        let attributedString = NSMutableAttributedString(string: firstPart, attributes: Self.tableRowViewStandardAttributes)
        let boldAttributedString = NSAttributedString(string: boldPart, attributes: Self.tableRowViewBoldAttributes)
        attributedString.append(boldAttributedString)

        return attributedString
    }

    var string: String {
        switch suggestion {
        case .phrase(phrase: let phrase):
            return phrase
        case .website(url: let url):
            return url.toString(forUserInput: userStringValue)
        case .historyEntry(title: let title, url: let url, allowedInTopHits: _):
            return title ?? url.toString(forUserInput: userStringValue)
        case .bookmark(title: let title, url: _, isFavorite: _):
            return title
        case .unknown(value: let value):
            return value
        }
    }

    var title: String? {
        switch suggestion {
        case .phrase(phrase: _),
             .website(url: _),
             .unknown(value: _):
            return nil
        case .historyEntry(title: let title, url: _, allowedInTopHits: _):
            return title
        case .bookmark(title: let title, url: _, isFavorite: _):
            return title
        }
    }

    var autocompletionString: String {
        switch suggestion {
        case .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .bookmark(title: _, url: let url, isFavorite: _):

            let userStringValue = self.userStringValue.lowercased()
            let urlString = url.toString(forUserInput: userStringValue)
            if !urlString.hasPrefix(userStringValue),
               let title = self.title,
               title.lowercased().hasPrefix(userStringValue) {
                return title
            }

            return urlString

        default:
            return self.string
        }
    }

    var suffix: String {
        switch suggestion {
        // for punycoded urls display real url as a suffix
        case .website(url: let url) where url.toString(forUserInput: userStringValue, decodePunycode: false) != self.string:
            return " – " + url.toString(decodePunycode: false, dropScheme: true, needsWWW: false, dropTrailingSlash: true)

        case .phrase, .unknown, .website:
            return ""
        case .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .bookmark(title: _, url: let url, isFavorite: _):
            return " – " + url.toString(decodePunycode: true,
                                        dropScheme: true,
                                        needsWWW: false,
                                        dropTrailingSlash: true)
        }
    }

    // MARK: - Icon

    static let webImage = NSImage(named: "Web")
    static let searchImage = NSImage(named: "Search")
    static let historyImage = NSImage(named: "HistorySuggestion")
    static let bookmarkImage = NSImage(named: "BookmarkSuggestion")
    static let favoriteImage = NSImage(named: "FavoritedBookmarkSuggestion")

    var icon: NSImage? {
        switch suggestion {
        case .phrase(phrase: _):
            return Self.searchImage
        case .website(url: _):
            return Self.webImage
        case .historyEntry(title: _, url: _, allowedInTopHits: _):
            return Self.historyImage
        case .bookmark(title: _, url: _, isFavorite: false):
            return Self.bookmarkImage
        case .bookmark(title: _, url: _, isFavorite: true):
            return Self.favoriteImage
        case .unknown(value: _):
            return Self.webImage
        }
    }

}
