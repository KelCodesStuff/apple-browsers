//
//  DefaultBrowserInfoStore.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Core

protocol DefaultBrowserInfoStorage: AnyObject {
    var defaultBrowserInfo: DefaultBrowserInfo? { get set }
}

final class DefaultBrowserInfoStore: DefaultBrowserInfoStorage {

    @UserDefaultsWrapper(key: .defaultBrowserInfo, defaultValue: nil)
    private var defaultBrowserInfoData: Data?

    var defaultBrowserInfo: DefaultBrowserInfo? {
        get {
            guard let data = defaultBrowserInfoData else { return nil }
            return try? JSONDecoder().decode(DefaultBrowserInfo.self, from: data)
        }
        set {
            defaultBrowserInfoData = try? newValue.flatMap(JSONEncoder().encode)
        }
    }
    
}
