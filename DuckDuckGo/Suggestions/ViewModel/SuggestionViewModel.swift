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

class SuggestionViewModel {

    static let webImage = NSImage(named: "Web")
    static let searchImage = NSImage(named: "Search")

    let suggestion: Suggestion

    init(suggestion: Suggestion) {
        if case .phrase(phrase: let phrase) = suggestion, let url = phrase.url, url.isValid {
            self.suggestion = .website(url: url, title: nil)
        } else {
            self.suggestion = suggestion
        }
    }

    var attributedString: NSAttributedString {
        let attributes = [NSAttributedString.Key.foregroundColor: NSColor.labelColor]

        switch suggestion {
        case .phrase(phrase: let phrase):
            return NSMutableAttributedString(string: phrase, attributes: attributes)
        case .website(url: let url, title: let title):
            if let title = title, title.count > 0 {
                return NSAttributedString(string: "\(title) - \(url.absoluteStringWithoutScheme)", attributes: attributes)
            } else {
                return NSAttributedString(string: "\(url.absoluteStringWithoutScheme)", attributes: attributes)
            }
        case .unknown(value: let value):
            return NSAttributedString(string: value, attributes: attributes)
        }
    }

    var icon: NSImage? {
        switch suggestion {
        case .phrase(phrase: _):
            return Self.searchImage
        case .website(url: _, title: _):
            return Self.webImage
        case .unknown(value: _):
            return Self.webImage
        }
    }

}

fileprivate extension URL {

    var absoluteStringWithoutScheme: String {
        if let scheme = scheme {
            return absoluteString.dropPrefix(scheme + "://")
        } else {
            return absoluteString
        }
    }

}
