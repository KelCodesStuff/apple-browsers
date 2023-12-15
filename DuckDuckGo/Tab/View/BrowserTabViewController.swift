//
//  BrowserTabViewController.swift
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
import WebKit
import Combine
import Common
import SwiftUI
import BrowserServicesKit

final class BrowserTabViewController: NSViewController {
    @IBOutlet var errorView: NSView!
    @IBOutlet var homePageView: NSView!
    @IBOutlet var errorMessageLabel: NSTextField!
    @IBOutlet var hoverLabel: NSTextField!
    @IBOutlet var hoverLabelContainer: NSView!
    private weak var webView: WebView?
    private weak var webViewContainer: NSView?
    private weak var webViewSnapshot: NSView?

    var tabViewModel: TabViewModel?

    private let tabCollectionViewModel: TabCollectionViewModel

    private var tabContentCancellable: AnyCancellable?
    private var userDialogsCancellable: AnyCancellable?
    private var activeUserDialogCancellable: Cancellable?
    private var errorViewStateCancellable: AnyCancellable?
    private var hoverLinkCancellable: AnyCancellable?
    private var pinnedTabsDelegatesCancellable: AnyCancellable?
    private var keyWindowSelectedTabCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var mouseDownCancellable: AnyCancellable?

    private weak var previouslySelectedTab: Tab?

    private var hoverLabelWorkItem: DispatchWorkItem?

    private var transientTabContentViewController: NSViewController?

    static func create(tabCollectionViewModel: TabCollectionViewModel) -> BrowserTabViewController {
        NSStoryboard(name: "BrowserTab", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel)
        }!
    }

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let homePageViewController = HomePageViewController(tabCollectionViewModel: tabCollectionViewModel, bookmarkManager: LocalBookmarkManager.shared)
        self.addAndLayoutChild(homePageViewController, into: homePageView)

        hoverLabelContainer.alphaValue = 0
        subscribeToTabs()
        subscribeToSelectedTabViewModel()
        subscribeToErrorViewState()

        view.registerForDraggedTypes([.URL, .fileURL])
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        addMouseMonitors()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        mouseDownCancellable = nil
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification,
                                               object: self.view.window)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDuckDuckGoEmailIncontextSignup),
                                               name: .emailDidIncontextSignup,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onCloseDuckDuckGoEmailProtection),
                                               name: .emailDidCloseEmailProtection,
                                               object: nil)

#if DBP
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onCloseDataBrokerProtection),
                                               name: .dbpDidClose,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDataBrokerWaitlistGetStartedPressedByUser),
                                               name: .dataBrokerProtectionUserPressedOnGetStartedOnWaitlist,
                                               object: nil)

#endif

#if SUBSCRIPTION
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onCloseSubscriptionPage),
                                               name: .subscriptionPageCloseAndOpenPreferences,
                                               object: nil)
#endif
    }

    @objc
    private func windowWillClose(_ notification: NSNotification) {
        self.removeWebViewFromHierarchy()
    }

    @objc
    private func onDuckDuckGoEmailIncontextSignup(_ notification: Notification) {
        guard WindowControllersManager.shared.lastKeyMainWindowController === self.view.window?.windowController else { return }

        self.previouslySelectedTab = tabCollectionViewModel.selectedTab
        let tab = Tab(content: .url(EmailUrls().emailProtectionInContextSignupLink, source: .ui), shouldLoadInBackground: true, burnerMode: tabCollectionViewModel.burnerMode)
        tabCollectionViewModel.append(tab: tab)
    }

    @objc
    private func onCloseDuckDuckGoEmailProtection(_ notification: Notification) {
        guard WindowControllersManager.shared.lastKeyMainWindowController === self.view.window?.windowController,
              let previouslySelectedTab else { return }

        if let activeTab = tabCollectionViewModel.selectedTabViewModel?.tab,
           let url = activeTab.url,
           EmailUrls().isDuckDuckGoEmailProtection(url: url) {

            self.closeTab(activeTab)
        }

        tabCollectionViewModel.select(tab: previouslySelectedTab)
        previouslySelectedTab.webView.evaluateJavaScript("window.openAutofillAfterClosingEmailProtectionTab()", in: nil, in: WKContentWorld.defaultClient)
        self.previouslySelectedTab = nil
    }

#if DBP
    @objc
    private func onCloseDataBrokerProtection(_ notification: Notification) {
        guard let activeTab = tabCollectionViewModel.selectedTabViewModel?.tab,
              view.window?.isKeyWindow == true else { return }

        self.closeTab(activeTab)

        if let previouslySelectedTab = self.previouslySelectedTab {
            tabCollectionViewModel.select(tab: previouslySelectedTab)
            self.previouslySelectedTab = nil
        }
    }

    @objc
    private func onDataBrokerWaitlistGetStartedPressedByUser(_ notification: Notification) {
        WindowControllersManager.shared.showDataBrokerProtectionTab()
    }

#endif

#if SUBSCRIPTION
    @objc
    private func onCloseSubscriptionPage(_ notification: Notification) {
        guard let activeTab = tabCollectionViewModel.selectedTabViewModel?.tab else { return }
        self.closeTab(activeTab)

        if let previouslySelectedTab = self.previouslySelectedTab {
            tabCollectionViewModel.select(tab: previouslySelectedTab)
            self.previouslySelectedTab = nil
        }

        openNewTab(with: .preferences(pane: .subscription))
    }
#endif

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel
            .sink { [weak self] selectedTabViewModel in

                guard let self = self else { return }
                self.tabViewModel = selectedTabViewModel
                self.showTabContent(of: selectedTabViewModel)
                self.subscribeToErrorViewState()
                self.subscribeToTabContent(of: selectedTabViewModel)
                self.subscribeToHoveredLink(of: selectedTabViewModel)
                self.subscribeToUserDialogs(of: selectedTabViewModel)
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabs() {
        tabCollectionViewModel.tabCollection.$tabs
            .sink(receiveValue: setDelegate())
            .store(in: &cancellables)
    }

    private func subscribeToPinnedTabs() {
        pinnedTabsDelegatesCancellable = tabCollectionViewModel.pinnedTabsCollection?.$tabs
            .sink(receiveValue: setDelegate())
    }

    private func setDelegate() -> ([Tab]) -> Void {
        { [weak self] (tabs: [Tab]) in
            guard let self else { return }
            for tab in tabs {
                tab.setDelegate(self)
                tab.autofill?.setDelegate(self)
                tab.downloads?.delegate = self
            }
        }
    }

    private func removeWebViewFromHierarchy(webView: WebView? = nil,
                                            container: NSView? = nil) {

        func removeWebInspectorFromHierarchy(container: NSView) {
            // Fixes the issue of web inspector unintentionally detaching from the parent view to a standalone window
            for subview in container.subviews where subview.className.contains("WKInspector") {
                subview.removeFromSuperview()
            }
        }

        guard let webView = webView ?? self.webView,
              let container = container ?? self.webViewContainer
        else { return }

        if self.webView === webView {
            self.webView = nil
        }

        if webView.window === view.window, webView.isInspectorShown {
            removeWebInspectorFromHierarchy(container: container)
        }
        container.removeFromSuperview()
        if self.webViewContainer === container {
            self.webViewContainer = nil
        }
    }

    private func addWebViewToViewHierarchy(_ webView: WebView, tab: Tab) {
        let container = WebViewContainerView(tab: tab, webView: webView, frame: view.bounds)
        self.webViewContainer = container
        view.addSubview(container)

        // Make sure link preview (tooltip shown in the bottom-left) is on top
        view.addSubview(hoverLabelContainer)
    }

    private func changeWebView(tabViewModel: TabViewModel?) {

        func cleanUpRemoteWebViewIfNeeded(_ webView: WebView) {
            if webView.containerView !== webViewContainer {
                webView.containerView?.removeFromSuperview()
            }
        }

        func displayWebView(of tabViewModel: TabViewModel) {
            let newWebView = tabViewModel.tab.webView
            cleanUpRemoteWebViewIfNeeded(newWebView)
            webView = newWebView

            addWebViewToViewHierarchy(newWebView, tab: tabViewModel.tab)
        }

        guard let tabViewModel = tabViewModel else {
            removeWebViewFromHierarchy()
            return
        }

        let oldWebView = webView
        let webViewContainer = webViewContainer

        displayWebView(of: tabViewModel)
        tabViewModel.updateAddressBarStrings()
        if let oldWebView = oldWebView, let webViewContainer = webViewContainer, oldWebView !== webView {
            removeWebViewFromHierarchy(webView: oldWebView, container: webViewContainer)
        }

        if setFirstResponderAfterAdding {
            setFirstResponderAfterAdding = false
            makeWebViewFirstResponder()
        }
    }

    private func subscribeToTabContent(of tabViewModel: TabViewModel?) {
        tabContentCancellable = tabViewModel?.tab.$content
            .dropFirst()
            .removeDuplicates(by: { old, new in
                // no need to call showTabContent if webView stays in place and only its URL changes
                if old.isUrl && new.isUrl {
                    return true
                }
                return old == new
            })
            .map { [weak tabViewModel] tabContent -> AnyPublisher<Void, Never> in
                guard let tabViewModel, tabContent.isUrl else {
                    return Just(()).eraseToAnyPublisher()
                }

                return Publishers.Merge3(
                    tabViewModel.tab.webViewDidCommitNavigationPublisher,
                    tabViewModel.tab.webViewDidFailNavigationPublisher,
                    tabViewModel.tab.webViewDidReceiveUserInteractiveChallengePublisher
                )
                .prefix(1)
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak tabViewModel] in
                guard let tabViewModel else { return }
                self?.showTabContent(of: tabViewModel)
            }
    }

    private func subscribeToUserDialogs(of tabViewModel: TabViewModel?) {
        userDialogsCancellable = nil
        guard let tabViewModel else { return }

        userDialogsCancellable = Publishers.CombineLatest(
            tabViewModel.tab.$userInteractionDialog,
            tabViewModel.tab.downloads?.savePanelDialogPublisher ?? Just(nil).eraseToAnyPublisher()
        )
        .map { $1 ?? $0 }
        .sink { [weak self] dialog in
            self?.show(dialog)
        }
    }

    private func subscribeToErrorViewState() {
        errorViewStateCancellable = tabViewModel?.$errorViewState.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(
                self?.tabViewModel?.errorViewState.isVisible ?? false,
                message: self?.tabViewModel?.errorViewState.message ?? UserText.unknownErrorMessage
            )
        }
    }

    func subscribeToHoveredLink(of tabViewModel: TabViewModel?) {
        hoverLinkCancellable = tabViewModel?.tab.hoveredLinkPublisher.sink { [weak self] in
            self?.scheduleHoverLabelUpdatesForUrl($0)
        }
    }

    func makeWebViewFirstResponder() {
        if let webView = self.webView {
            webView.makeMeFirstResponder()
        } else {
            setFirstResponderAfterAdding = true
            view.window?.makeFirstResponder(nil)
        }
    }

    private var setFirstResponderAfterAdding = false

    private func setFirstResponderIfNeeded() {
        guard webView?.url != nil else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.makeWebViewFirstResponder()
        }
    }

    private func displayErrorView(_ shown: Bool, message: String) {
        errorMessageLabel.stringValue = message
        errorView.isHidden = !shown
        webView?.isHidden = shown
        homePageView.isHidden = shown
    }

    func openNewTab(with content: Tab.TabContent) {
        guard tabCollectionViewModel.selectDisplayableTabIfPresent(content) == false else {
            return
        }

        // shouldn't open New Tabs in PopUp window
        if view.window?.isPopUpWindow ?? true {
            // Prefer Tab's Parent
            WindowControllersManager.shared.showTab(with: content)
            return
        }

        let tab = Tab(content: content,
                      shouldLoadInBackground: true,
                      burnerMode: tabCollectionViewModel.burnerMode,
                      webViewSize: view.frame.size)
        tabCollectionViewModel.append(tab: tab, selected: true)
    }

    // MARK: - Browser Tabs

    private func show(displayableTabAtIndex index: Int) {
        // The tab switcher only displays displayable tab types.
        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(Tab.TabContent.displayableTabTypes[index])
        showTabContent(of: tabCollectionViewModel.selectedTabViewModel)
    }

    private func removeAllTabContent(includingWebView: Bool = true) {
        self.homePageView.removeFromSuperview()
        transientTabContentViewController?.removeCompletely()
        preferencesViewController?.removeCompletely()
        bookmarksViewController?.removeCompletely()
#if DBP
        dataBrokerProtectionHomeViewController?.removeCompletely()
        dataBrokerProtectionHomeViewController = nil
#endif
        if includingWebView {
            self.removeWebViewFromHierarchy()
        }
    }

    private func showTransientTabContentController(_ vc: NSViewController) {
        transientTabContentViewController?.removeCompletely()
        addAndLayoutChild(vc)
        transientTabContentViewController = vc
    }

    private func requestDisableUI() {
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: true)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func showTabContent(of tabViewModel: TabViewModel?) {
        guard tabCollectionViewModel.allTabsCount > 0 else {
            view.window?.performClose(self)
            return
        }
        scheduleHoverLabelUpdatesForUrl(nil)

        switch tabViewModel?.tab.content {
        case .bookmarks:
            removeAllTabContent()
            addAndLayoutChild(bookmarksViewControllerCreatingIfNeeded())

        case let .preferences(pane):
            removeAllTabContent()
            let preferencesViewController = preferencesViewControllerCreatingIfNeeded()
            if let pane = pane, preferencesViewController.model.selectedPane != pane {
                preferencesViewController.model.selectPane(pane)
            }
            addAndLayoutChild(preferencesViewController)

        case .onboarding:
            removeAllTabContent()
            if !OnboardingViewModel().onboardingFinished {
                requestDisableUI()
            }
            showTransientTabContentController(OnboardingViewController.create(withDelegate: self))

        case .url:
            if shouldReplaceWebView(for: tabViewModel) {
                removeAllTabContent(includingWebView: true)
                changeWebView(tabViewModel: tabViewModel)
            }

        case .homePage:
            removeAllTabContent()
            view.addAndLayout(homePageView)

#if DBP
        case .dataBrokerProtection:
            removeAllTabContent()
            let dataBrokerProtectionViewController = dataBrokerProtectionHomeViewControllerCreatingIfNeeded()
            self.previouslySelectedTab = tabCollectionViewModel.selectedTab
            addAndLayoutChild(dataBrokerProtectionViewController)
#endif
        default:
            removeAllTabContent()
        }
    }

    private func shouldReplaceWebView(for tabViewModel: TabViewModel?) -> Bool {
        guard let tabViewModel = tabViewModel else {
            return false
        }

        let isPinnedTab = tabCollectionViewModel.pinnedTabsCollection?.tabs.contains(tabViewModel.tab) == true
        let isKeyWindow = view.window?.isKeyWindow == true

        let tabIsNotOnScreen = tabViewModel.tab.webView.tabContentView.superview == nil
        let isDifferentTabDisplayed = webView != tabViewModel.tab.webView

        return isDifferentTabDisplayed || tabIsNotOnScreen || (isPinnedTab && isKeyWindow)
    }

#if DBP
    // MARK: - DataBrokerProtection

    var dataBrokerProtectionHomeViewController: DBPHomeViewController?
    private func dataBrokerProtectionHomeViewControllerCreatingIfNeeded() -> DBPHomeViewController {
        return dataBrokerProtectionHomeViewController ?? {
            let dataBrokerProtectionHomeViewController = DBPHomeViewController(dataBrokerProtectionManager: DataBrokerProtectionManager.shared)
            self.dataBrokerProtectionHomeViewController = dataBrokerProtectionHomeViewController
            return dataBrokerProtectionHomeViewController
        }()
    }
#endif

    // MARK: - Preferences

    var preferencesViewController: PreferencesViewController?
    private func preferencesViewControllerCreatingIfNeeded() -> PreferencesViewController {
        return preferencesViewController ?? {
            let preferencesViewController = PreferencesViewController()
            preferencesViewController.delegate = self
            self.preferencesViewController = preferencesViewController
            return preferencesViewController
        }()
    }

    // MARK: - Bookmarks

    var bookmarksViewController: BookmarkManagementSplitViewController?
    private func bookmarksViewControllerCreatingIfNeeded() -> BookmarkManagementSplitViewController {
        return bookmarksViewController ?? {
            let bookmarksViewController = BookmarkManagementSplitViewController.create()
            bookmarksViewController.delegate = self
            self.bookmarksViewController = bookmarksViewController
            return bookmarksViewController
        }()
    }

    private var contentOverlayPopover: ContentOverlayPopover?
    private func contentOverlayPopoverCreatingIfNeeded() -> ContentOverlayPopover {
        return contentOverlayPopover ?? {
            let overlayPopover = ContentOverlayPopover(currentTabView: self.view)
            self.contentOverlayPopover = overlayPopover
            WindowControllersManager.shared.stateChanged
                .sink { [weak overlayPopover] _ in
                    overlayPopover?.viewController.closeContentOverlayPopover()
                }.store(in: &self.cancellables)
            return overlayPopover
        }()
    }

    // MARK: - Alerts

    private func showAlert(with query: JSAlertQuery) -> AnyCancellable {
        let jsAlertController = JSAlertController.create(query)
        present(jsAlertController, animator: jsAlertController)

        return AnyCancellable { [weak self] in
            self?.dismiss(jsAlertController)
        }
    }

}

extension BrowserTabViewController: NSDraggingDestination {

    func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard draggingInfo.draggingPasteboard.url != nil else { return .none }
        if let selectedTab = tabCollectionViewModel.selectedTab,
           selectedTab.isPinned {
            return .copy
        }

        return (NSApp.isCommandPressed || NSApp.isOptionPressed || !draggingInfo.draggingSourceOperationMask.contains(.move)) ? .copy : .move
    }

    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard let url = draggingInfo.draggingPasteboard.url else { return false }

        guard !(NSApp.isCommandPressed || NSApp.isOptionPressed),
              let selectedTab = tabCollectionViewModel.selectedTab,
              !selectedTab.isPinned else {

            self.openNewTab(with: .url(url, source: .appOpenUrl))
            return true
        }

        selectedTab.setContent(.url(url, source: .appOpenUrl))
        return true
    }

}

extension BrowserTabViewController: ContentOverlayUserScriptDelegate {
    public func websiteAutofillUserScriptCloseOverlay(_ websiteAutofillUserScript: WebsiteAutofillUserScript?) {
        contentOverlayPopoverCreatingIfNeeded().websiteAutofillUserScriptCloseOverlay(websiteAutofillUserScript)
    }
    public func websiteAutofillUserScript(_ websiteAutofillUserScript: WebsiteAutofillUserScript,
                                          willDisplayOverlayAtClick: NSPoint?,
                                          serializedInputContext: String,
                                          inputPosition: CGRect) {

        self.contentOverlayPopoverCreatingIfNeeded().websiteAutofillUserScript(websiteAutofillUserScript,
                                                                              willDisplayOverlayAtClick: willDisplayOverlayAtClick,
                                                                              serializedInputContext: serializedInputContext,
                                                                              inputPosition: inputPosition)

    }

}

extension BrowserTabViewController: TabDelegate {

    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool) {
        if isUserInitiated,
           let window = self.view.window,
           window.isPopUpWindow == true,
           window.isKeyWindow == false {

            window.makeKeyAndOrderFront(nil)
        }
    }

    func tabPageDOMLoaded(_ tab: Tab) {
        if tabViewModel?.tab == tab {
            tabViewModel?.isLoading = false
        }
    }

    func tabDidStartNavigation(_ tab: Tab) {
        setFirstResponderIfNeeded()
        guard let tabViewModel = tabViewModel else { return }

        tab.permissions.tabDidStartNavigation()
        if !tabViewModel.isLoading,
           tabViewModel.tab.webView.isLoading {
            tabViewModel.isLoading = true
        }
    }

    func tab(_ parentTab: Tab, createdChild childTab: Tab, of kind: NewWindowPolicy) {
        switch kind {
        case .popup(origin: let origin, size: let contentSize):
            WindowsManager.openPopUpWindow(with: childTab, origin: origin, contentSize: contentSize)
        case .window(active: let active, let isBurner):
            assert(isBurner == childTab.burnerMode.isBurner)
            WindowsManager.openNewWindow(with: childTab, showWindow: active)
        case .tab(selected: let selected, _):
            self.tabCollectionViewModel.insert(childTab, after: parentTab, selected: selected)
        }
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabCollectionViewModel.tabCollection.tabs.firstIndex(of: tab) else {
            return
        }
        tabCollectionViewModel.remove(at: .unpinned(index))
    }

    func tab(_ tab: Tab,
             requestedBasicAuthenticationChallengeWith protectionSpace: URLProtectionSpace,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let window = view.window else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let alert = AuthenticationAlert(host: protectionSpace.host, isEncrypted: protectionSpace.receivesCredentialSecurely)
        alert.beginSheetModal(for: window) { response in
            guard case .OK = response else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(user: alert.usernameTextField.stringValue,
                                                            password: alert.passwordTextField.stringValue,
                                                            persistence: .forSession))

        }
    }

    func windowDidBecomeKey() {
        keyWindowSelectedTabCancellable = nil
        subscribeToPinnedTabs()
        hideWebViewSnapshotIfNeeded()
    }

    func windowDidResignKey() {
        pinnedTabsDelegatesCancellable = nil
        scheduleHoverLabelUpdatesForUrl(nil)
        subscribeToTabSelectedInCurrentKeyWindow()
    }

    private func scheduleHoverLabelUpdatesForUrl(_ url: URL?) {
        // cancel previous animation, if any
        hoverLabelWorkItem?.cancel()

        // schedule an animation if needed
        var animationItem: DispatchWorkItem?
        var delay: Double = 0
        if url == nil && hoverLabelContainer.alphaValue > 0 {
            // schedule a fade out
            delay = 0.1
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabelContainer.animator().alphaValue = 0
            }
        } else if url != nil && hoverLabelContainer.alphaValue < 1 {
            // schedule a fade in
            delay = 0.5
            animationItem = DispatchWorkItem { [weak self] in
                self?.hoverLabel.stringValue = url?.absoluteString ?? ""
                self?.hoverLabelContainer.animator().alphaValue = 1
            }
        } else {
            hoverLabel.stringValue = url?.absoluteString ?? ""
        }

        if let item = animationItem {
            hoverLabelWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    func tab(_ tab: Tab, requestedSaveAutofillData autofillData: AutofillData) {
        tabViewModel?.autofillDataToSave = autofillData
    }

    // MARK: - Dialogs

    fileprivate func show(_ dialog: Tab.UserDialog?) {
        switch dialog?.dialog {
        case .basicAuthenticationChallenge(let query):
            activeUserDialogCancellable = showBasicAuthenticationChallenge(with: query)
        case .jsDialog(let query):
            activeUserDialogCancellable = showAlert(with: query)
        case .savePanel(let query):
            activeUserDialogCancellable = showSavePanel(with: query)
        case .openPanel(let query):
            activeUserDialogCancellable = showOpenPanel(with: query)
        case .print(let query):
            activeUserDialogCancellable = runPrintOperation(with: query)
        case .none:
            // modal sheet will close automatcially (or switch to another Tab‘s dialog) when switching tabs
            activeUserDialogCancellable = nil
        }
    }

    private func showBasicAuthenticationChallenge(with request: BasicAuthDialogRequest) -> ModalSheetCancellable? {
        guard let window = view.window else { return nil }

        let alert = AuthenticationAlert(host: request.parameters.host,
                                        isEncrypted: request.parameters.receivesCredentialSecurely)
        alert.beginSheetModal(for: window) { [request] response in
            // don‘t submit the query when tab is switched
            if case .abort = response { return }
            guard case .OK = response else {
                request.submit(nil)
                return
            }
            request.submit(.credential(URLCredential(user: alert.usernameTextField.stringValue,
                                                     password: alert.passwordTextField.stringValue,
                                                     persistence: .forSession)))
        }

        // when subscribing to another Tab, the sheet will be temporarily closed with response == .abort on the cancellable deinit
        return ModalSheetCancellable(ownerWindow: window, modalSheet: alert.window, condition: !request.isComplete)
    }

    func showSavePanel(with request: SavePanelDialogRequest) -> ModalSheetCancellable? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let window = view.window else { return nil }

        let savePanel = NSSavePanel.savePanelWithFileTypeChooser(fileTypes: request.parameters.fileTypes,
                                                                 suggestedFilename: request.parameters.suggestedFilename,
                                                                 directoryURL: DownloadsPreferences().effectiveDownloadLocation)

        savePanel.beginSheetModal(for: window) { [request] response in
            if case .abort = response {
                // panel not closed by user but by a tab switching
                return
            } else if case .OK = response, let url = savePanel.url {
                request.submit( (url, savePanel.selectedFileType) )
            } else {
                request.submit(nil)
            }
        }

        // when subscribing to another Tab, the sheet will be temporarily closed with response == .abort on the cancellable deinit
        return ModalSheetCancellable(ownerWindow: window, modalSheet: savePanel, condition: !request.isComplete)
    }

    func showOpenPanel(with request: OpenPanelDialogRequest) -> ModalSheetCancellable? {
        guard let window = view.window else { return nil }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = request.parameters.allowsMultipleSelection

        openPanel.beginSheetModal(for: window) { [request] response in
            // don‘t submit the query when tab is switched
            if case .abort = response { return }
            guard case .OK = response else {
                request.submit(nil)
                return
            }
            request.submit(openPanel.urls)
        }

        // when subscribing to another Tab, the sheet will be temporarily closed with response == .abort on the cancellable deinit
        return ModalSheetCancellable(ownerWindow: window, modalSheet: openPanel, condition: !request.isComplete)
    }

    private class PrintContext {
        let request: PrintDialogRequest
        weak var printPanel: NSWindow?
        var isAborted = false
        init(request: PrintDialogRequest) {
            self.request = request
        }
    }
    func runPrintOperation(with request: PrintDialogRequest) -> ModalSheetCancellable? {
        guard let window = view.window else { return nil }

        let printOperation = request.parameters
        let didRunSelector = #selector(printOperationDidRun(printOperation:success:contextInfo:))

        let windowSheetsBeforPrintOperation = window.sheets

        let context = PrintContext(request: request)
        let contextInfo = Unmanaged<PrintContext>.passRetained(context).toOpaque()

        printOperation.runModal(for: window, delegate: self, didRun: didRunSelector, contextInfo: contextInfo)

        // get the Print Panel that (hopefully) was added to the window.sheets
        context.printPanel = Set(window.sheets).subtracting(windowSheetsBeforPrintOperation).first

        // when subscribing to another Tab, the sheet will be temporarily closed with response == .abort on the cancellable deinit
        return ModalSheetCancellable(ownerWindow: window, modalSheet: context.printPanel, returnCode: nil, condition: !context.request.isComplete) {
            context.isAborted = true
        }
    }

    @objc private func printOperationDidRun(printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let contextInfo else {
            assertionFailure("could not get query")
            return
        }
        let context = Unmanaged<PrintContext>.fromOpaque(contextInfo).takeRetainedValue()

        // don‘t submit the query when tab is switched
        if context.isAborted { return }
        if let window = view.window, let printPanel = context.printPanel, window.sheets.contains(printPanel) {
            window.endSheet(printPanel)
        }

        context.request.submit(success)
    }

}

extension BrowserTabViewController: TabDownloadsDelegate {

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let window = self.view.window,
              let dockScreen = NSScreen.dockScreen
        else { return nil }

        // fly 64x64 icon from the center of Address Bar
        let size = view.bounds.size
        let rect = NSRect(x: size.width / 2 - 32, y: size.height / 2 - 32, width: 64, height: 64)
        let windowRect = view.convert(rect, to: nil)
        let globalRect = window.convertToScreen(windowRect)
        // to the Downloads folder in Dock (in DockScreen coordinates)
        let dockScreenRect = dockScreen.convert(globalRect)

        return dockScreenRect
    }

}

extension BrowserTabViewController: BrowserTabSelectionDelegate {

    func selectedTab(at index: Int) {
        show(displayableTabAtIndex: index)
    }

    func selectedPreferencePane(_ identifier: PreferencePaneIdentifier) {
        guard let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab else {
            return
        }

        if case .preferences = selectedTab.content {
            selectedTab.setContent(.preferences(pane: identifier))
        }
    }

}

extension BrowserTabViewController: OnboardingDelegate {

    func onboardingDidRequestImportData(completion: @escaping () -> Void) {
        DataImportViewController.show(completion: completion)
    }

    func onboardingDidRequestSetDefault(completion: @escaping () -> Void) {
        let defaultBrowserPreferences = DefaultBrowserPreferences()
        if defaultBrowserPreferences.isDefault {
            completion()
            return
        }

        defaultBrowserPreferences.becomeDefault { _ in
            _ = defaultBrowserPreferences
            withAnimation {
                completion()
            }
        }
    }

    func onboardingHasFinished() {
        (view.window?.windowController as? MainWindowController)?.userInteraction(prevented: false)
    }

}

extension BrowserTabViewController {

    func addMouseMonitors() {
        mouseDownCancellable = NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.mouseDown(with: event)
        }
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window else { return event }
        tabViewModel?.tab.autofill?.didClick(at: event.locationInWindow)
        return event
    }

}

// MARK: - Web View snapshot for Pinned Tab selected in more than 1 window

extension BrowserTabViewController {

    private func subscribeToTabSelectedInCurrentKeyWindow() {
        let lastKeyWindowOtherThanOurs = WindowControllersManager.shared.didChangeKeyWindowController
            .map { WindowControllersManager.shared.lastKeyMainWindowController }
            .prepend(WindowControllersManager.shared.lastKeyMainWindowController)
            .compactMap { $0 }
            .filter { [weak self] in $0.window !== self?.view.window }

        keyWindowSelectedTabCancellable = lastKeyWindowOtherThanOurs
            .flatMap(\.mainViewController.tabCollectionViewModel.$selectionIndex)
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] index in
                self?.handleTabSelectedInKeyWindow(index)
            }
    }

    private func handleTabSelectedInKeyWindow(_ tabIndex: TabIndex) {
        if tabIndex.isPinnedTab, tabIndex == tabCollectionViewModel.selectionIndex, webViewSnapshot == nil {
            makeWebViewSnapshot()
        } else {
            hideWebViewSnapshotIfNeeded()
        }
    }

    private func makeWebViewSnapshot() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let webView = webView else {
            os_log("BrowserTabViewController: failed to create a snapshot of webView", type: .error)
            return
        }

        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false

        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let image = image else {
                os_log("BrowserTabViewController: failed to create a snapshot of webView", type: .error)
                return
            }
            self?.showWebViewSnapshot(with: image)
        }
    }

    private func showWebViewSnapshot(with image: NSImage) {
        let snapshotView = WebViewSnapshotView(image: image, frame: view.bounds)
        snapshotView.autoresizingMask = [.width, .height]
        snapshotView.translatesAutoresizingMaskIntoConstraints = true

        view.addSubview(snapshotView)
        webViewSnapshot?.removeFromSuperview()
        webViewSnapshot = snapshotView
    }

    private func hideWebViewSnapshotIfNeeded() {
        if webViewSnapshot != nil {
            DispatchQueue.main.async {
                let isWebViewFirstResponder = self.view.window?.firstResponder === self.view.window
                // check this because if address bar was the first responder, we don't want to mess with it
                if isWebViewFirstResponder {
                    self.setFirstResponderAfterAdding = true
                }
                self.showTabContent(of: self.tabCollectionViewModel.selectedTabViewModel)
                self.webViewSnapshot?.removeFromSuperview()
            }
        }
    }
}
