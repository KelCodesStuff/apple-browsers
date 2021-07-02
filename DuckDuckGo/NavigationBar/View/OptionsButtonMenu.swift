//
//  OptionsButtonMenu.swift
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
import os.log
import WebKit
import BrowserServicesKit

protocol OptionsButtonMenuDelegate: AnyObject {

    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)

}

final class OptionsButtonMenu: NSMenu {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager

    enum Result {
        case moveTabToNewWindow
        case feedback
        case fireproof

        case emailProtection
        case emailProtectionOff
        case emailProtectionCreateAddress
        case emailProtectionDashboard

        case bookmarkThisPage
        case favoriteThisPage

        case bookmarks
        case preferences
    }

    fileprivate(set) var result: Result?

    required init(coder: NSCoder) {
        fatalError("OptionsButtonMenu: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager = EmailManager()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: "")

        setupMenuItems()
    }

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "")

    override func update() {
        self.result = nil
        super.update()
    }

    // swiftlint:disable function_body_length
    private func setupMenuItems() {
        let moveTabMenuItem = NSMenuItem(title: UserText.moveTabToNewWindow,
                                         action: #selector(moveTabToNewWindowAction(_:)),
                                         keyEquivalent: "")
        moveTabMenuItem.target = self
        moveTabMenuItem.image = NSImage(named: "MoveTabToNewWindow")
        addItem(moveTabMenuItem)

#if FEEDBACK

        let openFeedbackMenuItem = NSMenuItem(title: "Send Feedback",
                                              action: #selector(AppDelegate.openFeedback(_:)),
                                         keyEquivalent: "")
        openFeedbackMenuItem.image = NSImage(named: "Feedback")
        addItem(openFeedbackMenuItem)

#endif
        
        let emailItem = NSMenuItem(title: UserText.emailOptionsMenuItem,
                                   action: nil,
                                   keyEquivalent: "")
        emailItem.image = NSImage(named: "OptionsButtonMenuEmail")
        emailItem.submenu = EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager)
        addItem(emailItem)
    
        addItem(NSMenuItem.separator())

        zoomMenuItem.submenu = ZoomSubMenu(tabCollectionViewModel: tabCollectionViewModel)
        addItem(zoomMenuItem)

        addItem(NSMenuItem.separator())

        if let url = tabCollectionViewModel.selectedTabViewModel?.tab.url, url.canFireproof, let host = url.host {
            if FireproofDomains.shared.isAllowed(fireproofDomain: host) {

                let removeFireproofingItem = NSMenuItem(title: UserText.removeFireproofing,
                                                        action: #selector(toggleFireproofing(_:)),
                                                        keyEquivalent: "")
                removeFireproofingItem.target = self
                removeFireproofingItem.image = NSImage(named: "BurnProof")
                addItem(removeFireproofingItem)

            } else {

                let fireproofSiteItem = NSMenuItem(title: UserText.fireproofSite,
                                                   action: #selector(toggleFireproofing(_:)),
                                                   keyEquivalent: "")
                fireproofSiteItem.target = self
                fireproofSiteItem.image = NSImage(named: "BurnProof")
                addItem(fireproofSiteItem)

            }

            addItem(NSMenuItem.separator())
        }

        let bookmarksMenuItem = NSMenuItem(title: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
        bookmarksMenuItem.target = self
        bookmarksMenuItem.image = NSImage(named: "Bookmarks")
        addItem(bookmarksMenuItem)

        let preferencesItem = NSMenuItem(title: UserText.preferences, action: #selector(openPreferences(_:)), keyEquivalent: "")
        preferencesItem.target = self
        preferencesItem.image = NSImage(named: "Preferences")
        addItem(preferencesItem)
    }
    // swiftlint:enable function_body_length

    @objc func moveTabToNewWindowAction(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        let tab = selectedTabViewModel.tab
        tabCollectionViewModel.removeSelected()
        WindowsManager.openNewWindow(with: tab)
    }

    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        
        selectedTabViewModel.tab.requestFireproofToggle()
    }

    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        WindowControllersManager.shared.showPreferencesTab()
    }

    override func performActionForItem(at index: Int) {
        defer {
            super.performActionForItem(at: index)
        }

        guard let item = self.item(at: index) else {
            assertionFailure("MainViewController: No Menu Item at index \(index)")
            return
        }

        switch item.action {
        case #selector(moveTabToNewWindowAction(_:)):
            self.result = .moveTabToNewWindow
        case #selector(AppDelegate.openFeedback(_:)):
            self.result = .feedback
        case #selector(toggleFireproofing(_:)):
            self.result = .fireproof
        case #selector(openBookmarks(_:)):
            self.result = .bookmarks
        case #selector(openPreferences(_:)):
            self.result = .preferences
        case .none:
            break
        default:
            assertionFailure("MainViewController: no case for selector \(item.action!)")
        }
    }

}

final class EmailOptionsButtonSubMenu: NSMenu {
    
    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
        
    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: UserText.emailOptionsMenuItem)

        updateMenuItems()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignInNotification(_:)),
                                               name: .emailDidSignIn,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(emailDidSignOutNotification(_:)),
                                               name: .emailDidSignOut,
                                               object: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateMenuItems() {
        removeAllItems()
        if emailManager.isSignedIn {
            let createAddressItem = NSMenuItem(title: UserText.emailOptionsMenuCreateAddressSubItem,
                                           action: #selector(createAddressAction(_:)),
                                           keyEquivalent: "")
            createAddressItem.target = self
            createAddressItem.image = NSImage(named: "OptionsButtonMenuEmailGenerateAddress")
            addItem(createAddressItem)

            let turnOnOffItem = NSMenuItem(title: UserText.emailOptionsMenuTurnOffSubItem,
                                           action: #selector(turnOffEmailAction(_:)),
                                           keyEquivalent: "")
            turnOnOffItem.target = self
            turnOnOffItem.image = NSImage(named: "OptionsButtonMenuEmailDisabled")
            addItem(turnOnOffItem)
        } else {
            let turnOnOffItem = NSMenuItem(title: UserText.emailOptionsMenuTurnOnSubItem,
                                           action: #selector(turnOnEmailAction(_:)),
                                           keyEquivalent: "")
            turnOnOffItem.target = self
            turnOnOffItem.image = NSImage(named: "OptionsButtonMenuEmail")
            addItem(turnOnOffItem)
        }
    }
    
    @objc func createAddressAction(_ sender: NSMenuItem) {
         guard let url = emailManager.generateTokenPageURL else {
             assertionFailure("Could not get token page URL, token not available")
             return
         }
         let tab = Tab()
         tab.url = url
         tabCollectionViewModel.append(tab: tab)
         (supermenu as? OptionsButtonMenu)?.result = .emailProtectionCreateAddress
    }
    
    @objc func viewDashboardAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = EmailUrls().emailDashboardPage
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? OptionsButtonMenu)?.result = .emailProtectionDashboard
    }
    
    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        emailManager.signOut()

        (supermenu as? OptionsButtonMenu)?.result = .emailProtectionOff
    }
    
    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab()
        tab.url = EmailUrls().emailLandingPage
        tabCollectionViewModel.append(tab: tab)

        (supermenu as? OptionsButtonMenu)?.result = .emailProtection
    }

    @objc func emailDidSignInNotification(_ notification: Notification) {
        updateMenuItems()
    }
    
    @objc func emailDidSignOutNotification(_ notification: Notification) {
        updateMenuItems()
    }
}

final class ZoomSubMenu: NSMenu {

    init(tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.zoom)

        updateMenuItems(with: tabCollectionViewModel)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel) {
        removeAllItems()

        let fullScreenItem = (NSApplication.shared.mainMenuTyped.toggleFullscreenMenuItem?.copy() as? NSMenuItem)!
        addItem(fullScreenItem)

        addItem(.separator())

        let zoomInItem = (NSApplication.shared.mainMenuTyped.zoomInMenuItem?.copy() as? NSMenuItem)!
        addItem(zoomInItem)

        let zoomOutItem = (NSApplication.shared.mainMenuTyped.zoomOutMenuItem?.copy() as? NSMenuItem)!
        addItem(zoomOutItem)

        let actualSizeItem = (NSApplication.shared.mainMenuTyped.actualSizeMenuItem?.copy() as? NSMenuItem)!
        addItem(actualSizeItem)
    }

}
