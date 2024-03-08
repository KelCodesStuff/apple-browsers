//
//  MoreOptionsMenu.swift
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
import Combine
import Common
import BrowserServicesKit

#if NETWORK_PROTECTION
import NetworkProtection
#endif

#if SUBSCRIPTION
import Subscription
#endif

protocol OptionsButtonMenuDelegate: AnyObject {

    func optionsButtonMenuRequestedBookmarkThisPage(_ sender: NSMenuItem)
    func optionsButtonMenuRequestedBookmarkPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkManagementInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkImportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedBookmarkExportInterface(_ menu: NSMenu)
    func optionsButtonMenuRequestedLoginsPopover(_ menu: NSMenu, selectedCategory: SecureVaultSorting.Category)
    func optionsButtonMenuRequestedOpenExternalPasswordManager(_ menu: NSMenu)
    func optionsButtonMenuRequestedNetworkProtectionPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedDownloadsPopover(_ menu: NSMenu)
    func optionsButtonMenuRequestedPrint(_ menu: NSMenu)
    func optionsButtonMenuRequestedPreferences(_ menu: NSMenu)
    func optionsButtonMenuRequestedAppearancePreferences(_ menu: NSMenu)
#if DBP
    func optionsButtonMenuRequestedDataBrokerProtection(_ menu: NSMenu)
#endif
#if SUBSCRIPTION
    func optionsButtonMenuRequestedSubscriptionPurchasePage(_ menu: NSMenu)
    func optionsButtonMenuRequestedIdentityTheftRestoration(_ menu: NSMenu)
#endif
}

@MainActor
final class MoreOptionsMenu: NSMenu {

    weak var actionDelegate: OptionsButtonMenuDelegate?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private let passwordManagerCoordinator: PasswordManagerCoordinating
    private let internalUserDecider: InternalUserDecider
    private lazy var sharingMenu: NSMenu = SharingMenu(title: UserText.shareMenuItem)

#if NETWORK_PROTECTION
    private let networkProtectionFeatureVisibility: NetworkProtectionFeatureVisibility
#endif

    required init(coder: NSCoder) {
        fatalError("MoreOptionsMenu: Bad initializer")
    }

#if NETWORK_PROTECTION
    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager = EmailManager(),
         passwordManagerCoordinator: PasswordManagerCoordinator,
         networkProtectionFeatureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(),
         sharingMenu: NSMenu? = nil,
         internalUserDecider: InternalUserDecider) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.networkProtectionFeatureVisibility = networkProtectionFeatureVisibility
        self.internalUserDecider = internalUserDecider

        super.init(title: "")

        if let sharingMenu {
            self.sharingMenu = sharingMenu
        }
        self.emailManager.requestDelegate = self

        setupMenuItems()
    }
#else
    init(tabCollectionViewModel: TabCollectionViewModel,
         emailManager: EmailManager = EmailManager(),
         passwordManagerCoordinator: PasswordManagerCoordinator,
         sharingMenu: NSMenu? = nil,
         internalUserDecider: InternalUserDecider) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.internalUserDecider = internalUserDecider

        super.init(title: "")

        if let sharingMenu {
            self.sharingMenu = sharingMenu
        }
        self.emailManager.requestDelegate = self

        setupMenuItems()
    }
#endif

    let zoomMenuItem = NSMenuItem(title: UserText.zoom, action: nil, keyEquivalent: "")

    private func setupMenuItems() {

#if FEEDBACK
        let feedbackString: String = {
            guard internalUserDecider.isInternalUser else {
                return UserText.sendFeedback
            }
            return "\(UserText.sendFeedback) (version: \(AppVersion.shared.versionNumber).\(AppVersion.shared.buildNumber))"
        }()
        let feedbackMenuItem = NSMenuItem(title: feedbackString, action: nil, keyEquivalent: "")

        feedbackMenuItem.submenu = FeedbackSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)
        addItem(feedbackMenuItem)

        addItem(NSMenuItem.separator())

#endif // FEEDBACK

        addWindowItems()

        zoomMenuItem.submenu = ZoomSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)
        addItem(zoomMenuItem)

        addItem(NSMenuItem.separator())

        addUtilityItems()

        addItem(withTitle: UserText.emailOptionsMenuItem, action: nil, keyEquivalent: "")
            .withImage(.optionsButtonMenuEmail)
            .withSubmenu(EmailOptionsButtonSubMenu(tabCollectionViewModel: tabCollectionViewModel, emailManager: emailManager))

        addItem(NSMenuItem.separator())

        addSubscriptionItems()

        addPageItems()

        let preferencesItem = NSMenuItem(title: UserText.settings, action: #selector(openPreferences(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.preferences)
        addItem(preferencesItem)
    }

#if DBP
    @objc func openDataBrokerProtection(_ sender: NSMenuItem) {
        #if SUBSCRIPTION
        actionDelegate?.optionsButtonMenuRequestedDataBrokerProtection(self)
        #else
        if !DefaultDataBrokerProtectionFeatureVisibility.bypassWaitlist && DataBrokerProtectionWaitlistViewControllerPresenter.shouldPresentWaitlist() {
            DataBrokerProtectionWaitlistViewControllerPresenter.show()
        } else {
            actionDelegate?.optionsButtonMenuRequestedDataBrokerProtection(self)
        }
        #endif
    }
#endif // DBP

    @objc func showNetworkProtectionStatus(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedNetworkProtectionPopover(self)
    }

    @objc func newTab(_ sender: NSMenuItem) {
        tabCollectionViewModel.appendNewTab()
    }

    @objc func newWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow()
    }

    @objc func newBurnerWindow(_ sender: NSMenuItem) {
        WindowsManager.openNewWindow(burnerMode: BurnerMode(isBurner: true))
    }

    @objc func toggleFireproofing(_ sender: NSMenuItem) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        selectedTabViewModel.tab.requestFireproofToggle()
    }

    @objc func bookmarkPage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkThisPage(sender)
    }

    @objc func openBookmarks(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkPopover(self)
    }

    @objc func openBookmarksManagementInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkManagementInterface(self)
    }

    @objc func openBookmarkImportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkImportInterface(self)
    }

    @objc func openBookmarkExportInterface(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedBookmarkExportInterface(self)
    }

    @objc func openDownloads(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedDownloadsPopover(self)
    }

    @objc func openAutofillWithAllItems(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .allItems)
    }

    @objc func openAutofillWithLogins(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .logins)
    }

    @objc func openExternalPasswordManager(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedOpenExternalPasswordManager(self)
    }

    @objc func openAutofillWithIdentities(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .identities)
    }

    @objc func openAutofillWithCreditCards(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedLoginsPopover(self, selectedCategory: .cards)
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPreferences(self)
    }

    @objc func openAppearancePreferences(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedAppearancePreferences(self)
    }

#if SUBSCRIPTION
    @objc func openSubscriptionPurchasePage(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedSubscriptionPurchasePage(self)
    }

    @objc func openIdentityTheftRestoration(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedIdentityTheftRestoration(self)
    }
#endif

    @objc func findInPage(_ sender: NSMenuItem) {
        tabCollectionViewModel.selectedTabViewModel?.showFindInPage()
    }

    @objc func doPrint(_ sender: NSMenuItem) {
        actionDelegate?.optionsButtonMenuRequestedPrint(self)
    }

    private func addWindowItems() {
        // New Tab
        addItem(withTitle: UserText.plusButtonNewTabMenuItem, action: #selector(newTab(_:)), keyEquivalent: "t")
            .targetting(self)
            .withImage(.add)

        // New Window
        addItem(withTitle: UserText.newWindowMenuItem, action: #selector(newWindow(_:)), keyEquivalent: "n")
            .targetting(self)
            .withImage(.newWindow)

        // New Burner Window
        let burnerWindowItem = NSMenuItem(title: UserText.newBurnerWindowMenuItem,
                                          action: #selector(newBurnerWindow(_:)),
                                          target: self)
        burnerWindowItem.keyEquivalent = "n"
        burnerWindowItem.keyEquivalentModifierMask = [.command, .shift]
        burnerWindowItem.image = .newBurnerWindow
        addItem(burnerWindowItem)

        addItem(NSMenuItem.separator())
    }

    private func addUtilityItems() {
        let bookmarksSubMenu = BookmarksSubMenu(targetting: self, tabCollectionViewModel: tabCollectionViewModel)

        addItem(withTitle: UserText.bookmarks, action: #selector(openBookmarks), keyEquivalent: "")
            .targetting(self)
            .withImage(.bookmarks)
            .withSubmenu(bookmarksSubMenu)

        addItem(withTitle: UserText.downloads, action: #selector(openDownloads), keyEquivalent: "j")
            .targetting(self)
            .withImage(.downloads)

        let loginsSubMenu = LoginsSubMenu(targetting: self,
                                          passwordManagerCoordinator: passwordManagerCoordinator)

        addItem(withTitle: UserText.passwordManagement, action: #selector(openAutofillWithAllItems), keyEquivalent: "")
            .targetting(self)
            .withImage(.passwordManagement)
            .withSubmenu(loginsSubMenu)

        addItem(NSMenuItem.separator())
    }

    private func addSubscriptionItems() {
        var items: [NSMenuItem] = []

#if SUBSCRIPTION
        if DefaultSubscriptionFeatureAvailability().isFeatureAvailable() && !AccountManager().isUserAuthenticated {
            items.append(contentsOf: makeInactiveSubscriptionItems())
        } else {
            items.append(contentsOf: makeActiveSubscriptionItems()) // this adds NETP and DBP only if conditionally enabled
        }
#else
        items.append(contentsOf: makeActiveSubscriptionItems()) // this adds NETP and DBP only if conditionally enabled
#endif

        if !items.isEmpty {
            items.forEach { addItem($0) }
            addItem(NSMenuItem.separator())
        }
    }

    // swiftlint:disable:next function_body_length
    private func makeActiveSubscriptionItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

#if NETWORK_PROTECTION
        if networkProtectionFeatureVisibility.isNetworkProtectionVisible() {
            let isWaitlistUser = NetworkProtectionWaitlist().waitlistStorage.isWaitlistUser
            let hasAuthToken = NetworkProtectionKeychainTokenStore().isFeatureActivated

            let networkProtectionItem: NSMenuItem

            // If the user can see the Network Protection option but they haven't joined the waitlist or don't have an auth token, show the "New"
            // badge to bring it to their attention.
            if !isWaitlistUser && !hasAuthToken {
                networkProtectionItem = makeNetworkProtectionItem(showNewLabel: true)
            } else {
                networkProtectionItem = makeNetworkProtectionItem(showNewLabel: false)
            }

            items.append(networkProtectionItem)

#if SUBSCRIPTION
            Task {
                let isMenuItemEnabled: Bool

                switch await AccountManager().hasEntitlement(for: .networkProtection) {
                case let .success(result):
                    isMenuItemEnabled = result
                case .failure:
                    isMenuItemEnabled = false
                }

                networkProtectionItem.isEnabled = isMenuItemEnabled
            }
#endif

            DailyPixel.fire(pixel: .networkProtectionWaitlistEntryPointMenuItemDisplayed, frequency: .dailyAndCount, includeAppVersionParameter: true)
        } else {
            networkProtectionFeatureVisibility.disableForWaitlistUsers()
        }
#endif // NETWORK_PROTECTION

#if DBP
        if DefaultDataBrokerProtectionFeatureVisibility().isFeatureVisible() {
            let dataBrokerProtectionItem = NSMenuItem(title: UserText.dataBrokerProtectionOptionsMenuItem,
                                                      action: #selector(openDataBrokerProtection),
                                                      keyEquivalent: "")
                .targetting(self)
                .withImage(.dbpIcon)
            items.append(dataBrokerProtectionItem)

#if SUBSCRIPTION
            Task {
                let isMenuItemEnabled: Bool

                switch await AccountManager().hasEntitlement(for: .dataBrokerProtection) {
                case let .success(result):
                    isMenuItemEnabled = result
                case .failure:
                    isMenuItemEnabled = false
                }

                dataBrokerProtectionItem.isEnabled = isMenuItemEnabled
            }
#endif

            DataBrokerProtectionExternalWaitlistPixels.fire(pixel: .dataBrokerProtectionWaitlistEntryPointMenuItemDisplayed, frequency: .dailyAndCount)

        } else {
            DefaultDataBrokerProtectionFeatureVisibility().disableAndDeleteForWaitlistUsers()
        }
#endif // DBP

#if SUBSCRIPTION
        if AccountManager().isUserAuthenticated {
            let identityTheftRestorationItem = NSMenuItem(title: UserText.identityTheftRestorationOptionsMenuItem,
                                                          action: #selector(openIdentityTheftRestoration),
                                                          keyEquivalent: "")
                .targetting(self)
                .withImage(.itrIcon)
            items.append(identityTheftRestorationItem)

            Task {
                let isMenuItemEnabled: Bool

                switch await AccountManager().hasEntitlement(for: .identityTheftRestoration) {
                case let .success(result):
                    isMenuItemEnabled = result
                case .failure:
                    isMenuItemEnabled = false
                }

                identityTheftRestorationItem.isEnabled = isMenuItemEnabled
            }
        }
#endif

        return items
    }

#if SUBSCRIPTION
    private func makeInactiveSubscriptionItems() -> [NSMenuItem] {
        let dataBrokerProtectionItem = NSMenuItem(title: UserText.dataBrokerProtectionScanOptionsMenuItem,
                                                  action: #selector(openSubscriptionPurchasePage(_:)),
                                                  keyEquivalent: "")
            .targetting(self)
            .withImage(.dbpIcon)

        let privacyProItem = NSMenuItem(title: UserText.subscriptionOptionsMenuItem,
                                        action: #selector(openSubscriptionPurchasePage(_:)),
                                        keyEquivalent: "")
            .targetting(self)
            .withImage(.subscriptionIcon)

        return [dataBrokerProtectionItem, privacyProItem]
    }
#endif

    private func addPageItems() {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.content.url else { return }

        if url.canFireproof, let host = url.host {

            let isFireproof = FireproofDomains.shared.isFireproof(fireproofDomain: host)
            let title = isFireproof ? UserText.removeFireproofing : UserText.fireproofSite
            let image: NSImage = isFireproof ? .burn : .fireproof

            addItem(withTitle: title, action: #selector(toggleFireproofing(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(image)

        }

        addItem(withTitle: UserText.findInPageMenuItem, action: #selector(findInPage(_:)), keyEquivalent: "f")
            .targetting(self)
            .withImage(.findSearch)

        addItem(withTitle: UserText.shareMenuItem, action: nil, keyEquivalent: "")
            .targetting(self)
            .withImage(.share)
            .withSubmenu(sharingMenu)

        addItem(withTitle: UserText.printMenuItem, action: #selector(doPrint(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.print)

        addItem(NSMenuItem.separator())

    }

#if NETWORK_PROTECTION
    private func makeNetworkProtectionItem(showNewLabel: Bool) -> NSMenuItem {
        let networkProtectionItem = NSMenuItem(title: "", action: #selector(showNetworkProtectionStatus(_:)), keyEquivalent: "")
            .targetting(self)
            .withImage(.image(for: .vpnIcon))

        if showNewLabel {
            let attributedText = NSMutableAttributedString(string: UserText.networkProtection)
            attributedText.append(NSAttributedString(string: "  "))

            let imageAttachment = NSTextAttachment()
            imageAttachment.image = .newLabel
            imageAttachment.setImageHeight(height: 16, offset: .init(x: 0, y: -4))

            attributedText.append(NSAttributedString(attachment: imageAttachment))

            networkProtectionItem.attributedTitle = attributedText
        } else {
            networkProtectionItem.title = UserText.networkProtection
        }

        return networkProtectionItem
    }
#endif

}

@MainActor
final class EmailOptionsButtonSubMenu: NSMenu {

    private let tabCollectionViewModel: TabCollectionViewModel
    private let emailManager: EmailManager
    private var emailProtectionDidChangeCancellable: AnyCancellable?

    init(tabCollectionViewModel: TabCollectionViewModel, emailManager: EmailManager) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.emailManager = emailManager
        super.init(title: UserText.emailOptionsMenuItem)

        updateMenuItems()

        emailProtectionDidChangeCancellable = Publishers
            .Merge(
                NotificationCenter.default.publisher(for: .emailDidSignIn),
                NotificationCenter.default.publisher(for: .emailDidSignOut)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems()
            }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems() {
        removeAllItems()
        if emailManager.isSignedIn {
            addItem(withTitle: UserText.emailOptionsMenuCreateAddressSubItem, action: #selector(createAddressAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.optionsButtonMenuEmailGenerateAddress)

            addItem(withTitle: UserText.emailOptionsMenuManageAccountSubItem, action: #selector(manageAccountAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.identity16)

            addItem(.separator())

            addItem(withTitle: UserText.emailOptionsMenuTurnOffSubItem, action: #selector(turnOffEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.emailDisabled16)

        } else {
            addItem(withTitle: UserText.emailOptionsMenuTurnOnSubItem, action: #selector(turnOnEmailAction(_:)), keyEquivalent: "")
                .targetting(self)
                .withImage(.optionsButtonMenuEmail)

        }
    }

    @objc func manageAccountAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionAccountLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }

    @objc func createAddressAction(_ sender: NSMenuItem) {
        assert(emailManager.requestDelegate != nil, "No requestDelegate on emailManager")

        emailManager.getAliasIfNeededAndConsume { [weak self] alias, error in
            guard let self = self, let alias = alias else {
                assertionFailure(error?.localizedDescription ?? "Unexpected email error")
                return
            }

            let address = self.emailManager.emailAddressFor(alias)
            let pixelParameters = self.emailManager.emailPixelParameters
            self.emailManager.updateLastUseDate()

            Pixel.fire(.emailUserCreatedAlias, withAdditionalParameters: pixelParameters)

            NSPasteboard.general.copy(address)
            NotificationCenter.default.post(name: NSNotification.Name.privateEmailCopiedToClipboard, object: nil)
        }
    }

    @objc func turnOffEmailAction(_ sender: NSMenuItem) {
        let alert = NSAlert.disableEmailProtection()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            try? emailManager.signOut()
        }
    }

    @objc func turnOnEmailAction(_ sender: NSMenuItem) {
        let tab = Tab(content: .url(EmailUrls().emailProtectionLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }
}

@MainActor
final class FeedbackSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.sendFeedback)
        updateMenuItems(with: tabCollectionViewModel, targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, targetting target: AnyObject) {
        removeAllItems()

        let reportBrokenSiteItem = NSMenuItem(title: UserText.reportBrokenSite,
                                              action: #selector(AppDelegate.openReportBrokenSite(_:)),
                                              keyEquivalent: "")
            .withImage(.exclamation)
        addItem(reportBrokenSiteItem)

        let browserFeedbackItem = NSMenuItem(title: UserText.browserFeedback,
                                             action: #selector(AppDelegate.openFeedback(_:)),
                                             keyEquivalent: "")
            .withImage(.feedback)
        addItem(browserFeedbackItem)
    }
}

@MainActor
final class ZoomSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.zoom)

        updateMenuItems(with: tabCollectionViewModel, targetting: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with tabCollectionViewModel: TabCollectionViewModel, targetting target: AnyObject) {
        removeAllItems()

        let fullScreenItem = (NSApp.mainMenuTyped.toggleFullscreenMenuItem.copy() as? NSMenuItem)!
        addItem(fullScreenItem)

        addItem(.separator())

        let zoomInItem = (NSApp.mainMenuTyped.zoomInMenuItem.copy() as? NSMenuItem)!
        addItem(zoomInItem)

        let zoomOutItem = (NSApp.mainMenuTyped.zoomOutMenuItem.copy() as? NSMenuItem)!
        addItem(zoomOutItem)

        let actualSizeItem = (NSApp.mainMenuTyped.actualSizeMenuItem.copy() as? NSMenuItem)!
        addItem(actualSizeItem)

        addItem(.separator())

        let globalZoomSettingItem = NSMenuItem(title: UserText.defaultZoomPageMoreOptionsItem, action: #selector(MoreOptionsMenu.openAppearancePreferences(_:)), keyEquivalent: "")
            .targetting(target)
        addItem(globalZoomSettingItem)
    }
}

@MainActor
final class BookmarksSubMenu: NSMenu {

    init(targetting target: AnyObject, tabCollectionViewModel: TabCollectionViewModel) {
        super.init(title: UserText.passwordManagement)
        self.autoenablesItems = false
        addMenuItems(with: tabCollectionViewModel, target: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addMenuItems(with tabCollectionViewModel: TabCollectionViewModel, target: AnyObject) {
        let bookmarkPageItem = addItem(withTitle: UserText.bookmarkThisPage, action: #selector(MoreOptionsMenu.bookmarkPage(_:)), keyEquivalent: "d")
            .withModifierMask([.command])
            .targetting(target)

        bookmarkPageItem.isEnabled = tabCollectionViewModel.selectedTabViewModel?.canBeBookmarked == true

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.bookmarksShowToolbarPanel, action: #selector(MoreOptionsMenu.openBookmarks(_:)), keyEquivalent: "")
            .targetting(target)

        BookmarksBarMenuFactory.addToMenu(self)

        addItem(NSMenuItem.separator())

        if let favorites = LocalBookmarkManager.shared.list?.favoriteBookmarks {
            let favoriteViewModels = favorites.compactMap(BookmarkViewModel.init(entity:))
            let potentialItems = bookmarkMenuItems(from: favoriteViewModels)

            let favoriteMenuItems = potentialItems.isEmpty ? [NSMenuItem.empty] : potentialItems

            let favoritesItem = addItem(withTitle: UserText.favorites, action: nil, keyEquivalent: "")
            favoritesItem.submenu = NSMenu(items: favoriteMenuItems)
            favoritesItem.image = .favorite

            addItem(NSMenuItem.separator())
        }

        let bookmarkManager = LocalBookmarkManager.shared
        guard let entities = bookmarkManager.list?.topLevelEntities else {
            return
        }

        let bookmarkViewModels = entities.compactMap(BookmarkViewModel.init(entity:))
        let menuItems = bookmarkMenuItems(from: bookmarkViewModels, topLevel: true)

        self.items.append(contentsOf: menuItems)

        addItem(NSMenuItem.separator())

        addItem(withTitle: UserText.importBookmarks, action: #selector(MoreOptionsMenu.openBookmarkImportInterface(_:)), keyEquivalent: "")
            .targetting(target)

        let exportBookmarItem = NSMenuItem(title: UserText.exportBookmarks, action: #selector(MoreOptionsMenu.openBookmarkExportInterface(_:)), keyEquivalent: "").targetting(target)
        exportBookmarItem.isEnabled = bookmarkManager.list?.totalBookmarks != 0
        addItem(exportBookmarItem)

    }

    private func bookmarkMenuItems(from bookmarkViewModels: [BookmarkViewModel], topLevel: Bool = true) -> [NSMenuItem] {
        var menuItems = [NSMenuItem]()

        if !topLevel {
            let showOpenInTabsItem = bookmarkViewModels.compactMap { $0.entity as? Bookmark }.count > 1
            if showOpenInTabsItem {
                menuItems.append(NSMenuItem(bookmarkViewModels: bookmarkViewModels))
                menuItems.append(.separator())
            }
        }

        for viewModel in bookmarkViewModels {
            let menuItem = NSMenuItem(bookmarkViewModel: viewModel)

            if let folder = viewModel.entity as? BookmarkFolder {
                let subMenu = NSMenu(title: folder.title)
                let childViewModels = folder.children.map(BookmarkViewModel.init)
                let childMenuItems = bookmarkMenuItems(from: childViewModels, topLevel: false)
                subMenu.items = childMenuItems

                if !subMenu.items.isEmpty {
                    menuItem.submenu = subMenu
                }
            }

            menuItems.append(menuItem)
        }

        return menuItems
    }

}

final class LoginsSubMenu: NSMenu {
    let passwordManagerCoordinator: PasswordManagerCoordinating

    init(targetting target: AnyObject, passwordManagerCoordinator: PasswordManagerCoordinating) {
        self.passwordManagerCoordinator = passwordManagerCoordinator
        super.init(title: UserText.passwordManagement)
        updateMenuItems(with: target)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateMenuItems(with target: AnyObject) {
        addItem(withTitle: UserText.passwordManagementAllItems, action: #selector(MoreOptionsMenu.openAutofillWithAllItems), keyEquivalent: "")
            .targetting(target)

        addItem(NSMenuItem.separator())

        let autofillSelector: Selector
        let autofillTitle: String

        if passwordManagerCoordinator.isEnabled {
            autofillSelector = #selector(MoreOptionsMenu.openExternalPasswordManager)
            autofillTitle = "\(UserText.passwordManagementLogins) (\(UserText.openIn(value: passwordManagerCoordinator.displayName)))"
        } else {
            autofillSelector = #selector(MoreOptionsMenu.openAutofillWithLogins)
            autofillTitle = UserText.passwordManagementLogins
        }

        addItem(withTitle: autofillTitle, action: autofillSelector, keyEquivalent: "")
            .targetting(target)
            .withImage(.loginGlyph)

        addItem(withTitle: UserText.passwordManagementIdentities, action: #selector(MoreOptionsMenu.openAutofillWithIdentities), keyEquivalent: "")
            .targetting(target)
            .withImage(.identityGlyph)

        addItem(withTitle: UserText.passwordManagementCreditCards, action: #selector(MoreOptionsMenu.openAutofillWithCreditCards), keyEquivalent: "")
            .targetting(target)
            .withImage(.creditCardGlyph)
    }

}

extension MoreOptionsMenu: EmailManagerRequestDelegate {}
