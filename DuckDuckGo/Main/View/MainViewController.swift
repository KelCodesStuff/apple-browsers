//
//  MainViewController.swift
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
import Carbon.HIToolbox
import Combine
import os.log

final class MainViewController: NSViewController {

    @IBOutlet weak var tabBarContainerView: NSView!
    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!
    @IBOutlet weak var findInPageContainerView: NSView!
    @IBOutlet var navigationBarTopConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet var webViewTopConstraint: NSLayoutConstraint!

    @IBOutlet var divider: NSView!

    private(set) var tabBarViewController: TabBarViewController!
    private(set) var navigationBarViewController: NavigationBarViewController!
    private(set) var browserTabViewController: BrowserTabViewController!
    private(set) var findInPageViewController: FindInPageViewController!
    private(set) var fireViewController: FireViewController!

    let tabCollectionViewModel: TabCollectionViewModel

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var navigationalCancellables = Set<AnyCancellable>()
    private var canBookmarkCancellable: AnyCancellable?
    private var canInsertLastRemovedTabCancellable: AnyCancellable?
    private var findInPageCancellable: AnyCancellable?
    private var keyDownMonitor: Any?
    private var mouseNavButtonsMonitor: Any?

    required init?(coder: NSCoder) {
        self.tabCollectionViewModel = TabCollectionViewModel()
        super.init(coder: coder)
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        listenToKeyDownEvents()
        subscribeToSelectedTabViewModel()
        findInPageContainerView.applyDropShadow()

    }

    override func viewWillAppear() {
        if view.window?.isPopUpWindow == true {
            tabBarViewController.view.isHidden = true
            tabBarContainerView.isHidden = true
            navigationBarTopConstraint.constant = 0.0
            webViewTopConstraint.constant = navigationBarViewController.view.frame.height
            addressBarHeightConstraint.constant = tabBarContainerView.frame.height
        } else {
            navigationBarContainerView.wantsLayer = true
            navigationBarContainerView.layer?.masksToBounds = false

            resizeNavigationBarForHomePage(tabCollectionViewModel.selectedTabViewModel?.tab.content == .homePage, animated: false)
        }
    }

    override func viewDidLayout() {
        findInPageContainerView.applyDropShadow()
    }

    func windowDidBecomeMain() {
        updateBackMenuItem()
        updateForwardMenuItem()
        updateReloadMenuItem()
        updateStopMenuItem()
    }

    func windowDidResignKey() {
        browserTabViewController.windowDidResignKey()
    }

    override func encodeRestorableState(with coder: NSCoder) {
        fatalError("Default AppKit State Restoration should not be used")
    }

    func windowWillClose() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = mouseNavButtonsMonitor {
            NSEvent.removeMonitor(monitor)
            mouseNavButtonsMonitor = nil
        }

        tabBarViewController?.hideTabPreview()
    }

    @IBSegueAction
    func createTabBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> TabBarViewController? {
        guard let tabBarViewController = TabBarViewController(coder: coder,
                                                              tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("MainViewController: Failed to init TabBarViewController")
        }

        self.tabBarViewController = tabBarViewController
        return tabBarViewController
    }

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController? {
        guard let navigationBarViewController = NavigationBarViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("MainViewController: Failed to init NavigationBarViewController")
        }

        self.navigationBarViewController = navigationBarViewController
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> BrowserTabViewController? {
        guard let browserTabViewController = BrowserTabViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("MainViewController: Failed to init BrowserTabViewController")
        }

        self.browserTabViewController = browserTabViewController
        return browserTabViewController
    }

    @IBSegueAction
    func createFindInPageViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> FindInPageViewController? {
        let findInPageViewController = FindInPageViewController(coder: coder)
        findInPageViewController?.delegate = self
        self.findInPageViewController = findInPageViewController
        return findInPageViewController
    }

    @IBSegueAction
    func createFireViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> FireViewController? {
        let fireViewController = FireViewController(coder: coder,
                                                    tabCollectionViewModel: tabCollectionViewModel)
        self.fireViewController = fireViewController
        return fireViewController
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.navigationalCancellables = []
            self?.subscribeToCanGoBackForward()
            self?.subscribeToFindInPage()
            self?.subscribeToTabContent()
            self?.adjustFirstResponder()
        }
    }

    private func resizeNavigationBarForHomePage(_ homePage: Bool, animated: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1

            let nonHomePageHeight: CGFloat = view.window?.isPopUpWindow == true ? 42 : 48

            let height = animated ? addressBarHeightConstraint.animator() : addressBarHeightConstraint
            height?.constant = homePage ? 56 : nonHomePageHeight

            let divider = animated ? self.divider.animator() : self.divider
            divider?.alphaValue = homePage ? 0 : 1.0

            navigationBarViewController.resizeAddressBarForHomePage(homePage, animated: animated)
        }
    }

    var lastTabContent: Tab.TabContent?
    private func subscribeToTabContent() {
        tabCollectionViewModel.selectedTabViewModel?.tab.$content.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] content in
            self?.resizeNavigationBarForHomePage(content == .homePage, animated: content == .homePage && self?.lastTabContent != .homePage)
            self?.lastTabContent = content
        }).store(in: &self.navigationalCancellables)
    }

    private func subscribeToFindInPage() {
        let model = tabCollectionViewModel.selectedTabViewModel?.findInPage
        model?.$visible.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateFindInPage()
        }.store(in: &self.navigationalCancellables)
    }

    private func subscribeToCanGoBackForward() {
        tabCollectionViewModel.selectedTabViewModel?.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateBackMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateForwardMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateReloadMenuItem()
        }.store(in: &self.navigationalCancellables)
        tabCollectionViewModel.selectedTabViewModel?.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateStopMenuItem()
        }.store(in: &self.navigationalCancellables)
    }

    private func updateFindInPage() {

        guard let model = tabCollectionViewModel.selectedTabViewModel?.findInPage else {
            findInPageViewController?.makeMeFirstResponder()
            os_log("MainViewController: Failed to get find in page model", type: .error)
            return
        }

        findInPageContainerView.isHidden = !model.visible
        findInPageViewController?.model = model
        if model.visible {
            findInPageViewController?.makeMeFirstResponder()
        }
    }

    private func updateBackMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let backMenuItem = NSApplication.shared.mainMenuTyped.backMenuItem else {
            assertionFailure("MainViewController: Failed to get reference to back menu item")
            return
        }

        backMenuItem.isEnabled = selectedTabViewModel.canGoBack
    }

    private func updateForwardMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let forwardMenuItem = NSApplication.shared.mainMenuTyped.forwardMenuItem else {
            assertionFailure("MainViewController: Failed to get reference to Forward menu item")
            return
        }

        forwardMenuItem.isEnabled = selectedTabViewModel.canGoForward
    }

    private func updateReloadMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let reloadMenuItem =  NSApplication.shared.mainMenuTyped.reloadMenuItem else {
            assertionFailure("MainViewController: Failed to get reference to Reload menu item")
            return
        }

        reloadMenuItem.isEnabled = selectedTabViewModel.canReload
    }

    private func updateStopMenuItem() {
        guard self.view.window?.isMainWindow == true else { return }
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }
        guard let stopMenuItem =  NSApplication.shared.mainMenuTyped.stopMenuItem else {
            assertionFailure("MainViewController: Failed to get reference to Stop menu item")
            return
        }

        stopMenuItem.isEnabled = selectedTabViewModel.isLoading
    }

    // MARK: - First responder

    func adjustFirstResponder() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("MainViewController: No tab view model selected", type: .error)
            return
        }

        switch selectedTabViewModel.tab.content {
        case .homePage, .onboarding, .none: navigationBarViewController.addressBarViewController?.addressBarTextField.makeMeFirstResponder()
        case .url:
            browserTabViewController.makeWebViewFirstResponder()
        case .preferences: browserTabViewController.preferencesViewController.view.makeMeFirstResponder()
        case .bookmarks: browserTabViewController.bookmarksViewController.view.makeMeFirstResponder()
        }

    }

}

// MARK: - Mouse & Keyboard Events

// This needs to be handled here or else there will be a "beep" even if handled in a different view controller. This now
//  matches Safari behaviour.
extension MainViewController {

    func listenToKeyDownEvents() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }

        self.keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return nil }
            return self.customKeyDown(with: event) ? nil : event
        }
        self.mouseNavButtonsMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            return self?.otherMouseUp(with: event)
        }
    }

    func customKeyDown(with event: NSEvent) -> Bool {
       guard let locWindow = self.view.window,
          NSApplication.shared.keyWindow === locWindow else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)

        switch Int(event.keyCode) {
        case kVK_Escape:
            var isHandled = false
            if !findInPageContainerView.isHidden {
                findInPageViewController?.findInPageDone(self)
                isHandled = true
            }
            if let addressBarVC = navigationBarViewController.addressBarViewController {
                isHandled = isHandled || addressBarVC.escapeKeyDown()
            }
            return isHandled

        // Handle critical Main Menu actions before WebView
        case kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6,
             kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
             kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
             kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8,
             kVK_ANSI_Keypad9:
            guard flags == .command else { return false }
            fallthrough
        case kVK_Tab where [[.control], [.control, .shift]].contains(flags),
             kVK_ANSI_N where flags == .command,
             kVK_ANSI_W where flags.contains(.command),
             kVK_ANSI_T where [[.command], [.command, .shift]].contains(flags),
             kVK_ANSI_Q where flags == .command,
             kVK_ANSI_R where flags == .command:
            guard view.window?.firstResponder is WebView else { return false }
            NSApp.menu?.performKeyEquivalent(with: event)
            return true

        default:
            return false
        }
    }

    func otherMouseUp(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window,
              self.webContainerView.isMouseLocationInsideBounds(event.locationInWindow)
        else { return event }

        if event.buttonNumber == 3,
           tabCollectionViewModel.selectedTabViewModel?.canGoBack == true {
            tabCollectionViewModel.selectedTabViewModel?.tab.goBack()
            return nil
        } else if event.buttonNumber == 4,
                  tabCollectionViewModel.selectedTabViewModel?.canGoForward == true {
            tabCollectionViewModel.selectedTabViewModel?.tab.goForward()
            return nil
        }

        return event

    }

}
