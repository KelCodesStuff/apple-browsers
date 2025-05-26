//
//  NewTabPageFavoritesActionsHandler.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppKit
import Foundation

public protocol NewTabPageFavorite {
    var id: String { get }
    var title: String { get }
    var url: String { get }
    var urlObject: URL? { get }
    var etldPlusOne: String? { get }
}

public protocol FavoritesActionsHandling {
    associatedtype FavoriteType: NewTabPageFavorite

    @MainActor func open(_ url: URL, sender: LinkOpenSender, target: LinkOpenTarget, setBurner: Bool?, in window: NSWindow?)
    @MainActor func open(_ url: URL, sender: LinkOpenSender, target: LinkOpenTarget, in window: NSWindow?)
    @MainActor func addNewFavorite(in window: NSWindow?)
    @MainActor func edit(_ favorite: FavoriteType, in window: NSWindow?)

    func copyLink(_ favorite: FavoriteType)

    func removeFavorite(_ favorite: FavoriteType)
    func deleteBookmark(for favorite: FavoriteType)
    func move(_ favoriteID: String, toIndex: Int)
}
