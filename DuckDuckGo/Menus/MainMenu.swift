//
//  MainMenu.swift
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
import os.log
import Combine

final class MainMenu: NSMenu {

    @IBOutlet weak var printSeparatorItem: NSMenuItem?
    @IBOutlet weak var printMenuItem: NSMenuItem?

    @IBOutlet weak var checkSpellingWhileTypingMenuItem: NSMenuItem?
    @IBOutlet weak var checkGrammarWithSpellingMenuItem: NSMenuItem?

    @IBOutlet weak var backMenuItem: NSMenuItem?
    @IBOutlet weak var forwardMenuItem: NSMenuItem?
    @IBOutlet weak var reloadMenuItem: NSMenuItem?
    @IBOutlet weak var stopMenuItem: NSMenuItem?
    @IBOutlet weak var homeMenuItem: NSMenuItem?
    @IBOutlet weak var reopenLastClosedTabMenuItem: NSMenuItem?

    @IBOutlet weak var bookmarksMenuItem: NSMenuItem?
    @IBOutlet weak var bookmarkThisPageMenuItem: NSMenuItem?
    @IBOutlet weak var favoritesMenuItem: NSMenuItem?
    @IBOutlet weak var favoriteThisPageMenuItem: NSMenuItem?

    @IBOutlet weak var debugMenuItem: NSMenuItem?

    @IBOutlet weak var helpMenuItem: NSMenuItem?
    @IBOutlet weak var helpSeparatorMenuItem: NSMenuItem?
    @IBOutlet weak var sendFeedbackMenuItem: NSMenuItem?

    @IBOutlet weak var toggleFullscreenMenuItem: NSMenuItem?
    @IBOutlet weak var zoomInMenuItem: NSMenuItem?
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem?
    @IBOutlet weak var actualSizeMenuItem: NSMenuItem?

    required init(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }
  
    override func update() {
        super.update()

        if #available(macOS 11, *) {
            // no-op
        } else {
            printMenuItem?.removeFromParent()
            printSeparatorItem?.removeFromParent()
        }
    }

    private func setup() {

#if !FEEDBACK

        guard let helpMenuItemSubmenu = helpMenuItem?.submenu,
              let helpSeparatorMenuItem = helpSeparatorMenuItem,
              let sendFeedbackMenuItem = sendFeedbackMenuItem else {
            os_log("MainMenuManager: Failed to setup main menu", type: .error)
            return
        }

        helpMenuItemSubmenu.removeItem(helpSeparatorMenuItem)
        helpMenuItemSubmenu.removeItem(sendFeedbackMenuItem)

#endif

#if !DEBUG

        if let item = debugMenuItem {
            removeItem(item)
        }

#endif

        subscribeToBookmarkList()
    }

    // MARK: - Bookmarks

    var bookmarkListCancellable: AnyCancellable?
    private func subscribeToBookmarkList() {
        bookmarkListCancellable = LocalBookmarkManager.shared.$list
            .compactMap({ $0?.bookmarks().map(BookmarkViewModel.init(bookmark:)) })
            .receive(on: DispatchQueue.main).sink { [weak self] bookmarkViewModels in
                self?.updateBookmarksMenu(bookmarkViewModels: bookmarkViewModels)
        }
    }

    func updateBookmarksMenu(bookmarkViewModels: [BookmarkViewModel]) {

        func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel]) -> [NSMenuItem] {
            bookmarkViewModels
                .filter { !$0.bookmark.isFavorite }
                .map { NSMenuItem(bookmarkViewModel: $0) }
        }

        func favoriteMenuItems(from bookmarkViewModels: [BookmarkViewModel]) -> [NSMenuItem] {
            bookmarkViewModels
                .filter { $0.bookmark.isFavorite }
                .enumerated()
                .map { index, bookmarkViewModel in
                    let item = NSMenuItem(bookmarkViewModel: bookmarkViewModel)
                    if index < 9 {
                        item.keyEquivalentModifierMask = [.option, .command]
                        item.keyEquivalent = String(index + 1)
                    }
                    return item
                }
        }

        guard let bookmarksMenu = bookmarksMenuItem?.submenu,
              let favoritesSeparatorIndex = bookmarksMenu.items.lastIndex(where: { $0.isSeparatorItem }),
              let favoritesMenuItem = favoritesMenuItem,
              let favoritesMenu = favoritesMenuItem.submenu,
              let favoriteThisPageSeparatorIndex = favoritesMenu.items.lastIndex(where: { $0.isSeparatorItem }) else {
            os_log("MainMenuManager: Failed to reference bookmarks menu items", type: .error)
            return
        }

        let cleanedBookmarkItems = bookmarksMenu.items.dropLast(bookmarksMenu.items.count - (favoritesSeparatorIndex + 1))
        let bookmarkItems = bookmarkMenuItems(from: bookmarkViewModels)
        bookmarksMenu.items = Array(cleanedBookmarkItems) + bookmarkItems

        let cleanedFavoriteItems = favoritesMenu.items.dropLast(favoritesMenu.items.count - (favoriteThisPageSeparatorIndex + 1))
        let favoriteItems = favoriteMenuItems(from: bookmarkViewModels)
        favoritesMenu.items = Array(cleanedFavoriteItems) + favoriteItems
    }

}

fileprivate extension NSMenuItem {
    
    convenience init(bookmarkViewModel: BookmarkViewModel) {
        self.init()
        
        title = bookmarkViewModel.menuTitle
        image = bookmarkViewModel.menuFavicon
        representedObject = bookmarkViewModel.bookmark
        action = #selector(MainViewController.navigateToBookmark(_:))
    }

    func removeFromParent() {
        parent?.submenu?.removeItem(self)
    }

}
