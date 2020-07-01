//
//  Suggestions.swift
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
import os.log

class Suggestions {

    let suggestionsAPI: SuggestionsAPI
    let suggestionsStore: SuggestionsStore

    @Published var items: [Suggestion] = []

    init(suggestionsAPI: SuggestionsAPI, suggestionsStore: SuggestionsStore) {
        self.suggestionsAPI = suggestionsAPI
        self.suggestionsStore = suggestionsStore
    }

    convenience init () {
        self.init(suggestionsAPI: DuckDuckGoSuggestionsAPI(), suggestionsStore: LocalSuggestionsStore())
    }

    func getSuggestions(for query: String) {
        if query == "" {
            items = []
            return
        }
        //todo get local

        suggestionsAPI.fetchSuggestions(for: query) { (suggestions, error) in
            guard let suggestions = suggestions, error == nil else {
                self.items = []
                os_log("Suggestions: Failed to fetch suggestions - ", log: OSLog.Category.general, type: .error, error?.localizedDescription ?? "")
                return
            }

            self.items = suggestions
        }
    }

    func saveSuggestion(url: URL) {
        //todo
    }

}
