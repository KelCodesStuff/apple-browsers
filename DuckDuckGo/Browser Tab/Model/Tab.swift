//
//  Tab.swift
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

// swiftlint:disable file_length

import Cocoa
import WebKit
import os
import Combine
import BrowserServicesKit
import Navigation
import TrackerRadarKit
import ContentBlocking
import UserScript
import Common
import PrivacyDashboard

protocol TabDelegate: ContentOverlayUserScriptDelegate {
    func tabWillStartNavigation(_ tab: Tab, isUserInitiated: Bool)
    func tabDidStartNavigation(_ tab: Tab)
    func tab(_ tab: Tab, createdChild childTab: Tab, of kind: NewWindowPolicy)

    func tab(_ tab: Tab, requestedOpenExternalURL url: URL, forUserEnteredURL userEntered: Bool) -> Bool
    func tab(_ tab: Tab, promptUserForCookieConsent result: @escaping (Bool) -> Void)

    func tabPageDOMLoaded(_ tab: Tab)
    func closeTab(_ tab: Tab)

}

// swiftlint:disable type_body_length
@dynamicMemberLookup
final class Tab: NSObject, Identifiable, ObservableObject {

    enum TabContent: Equatable {
        case homePage
        case url(URL, userEntered: Bool = false)
        case privatePlayer(videoID: String, timestamp: String?)
        case preferences(pane: PreferencePaneIdentifier?)
        case bookmarks
        case onboarding
        case none

        static func contentFromURL(_ url: URL?, userEntered: Bool = false) -> TabContent {
            if url == .homePage {
                return .homePage
            } else if url == .welcome {
                return .onboarding
            } else if url == .preferences {
                return .anyPreferencePane
            } else if let preferencePane = url.flatMap(PreferencePaneIdentifier.init(url:)) {
                return .preferences(pane: preferencePane)
            } else if let privatePlayerContent = PrivatePlayer.shared.tabContent(for: url) {
                return privatePlayerContent
            } else {
                return .url(url ?? .blankPage, userEntered: userEntered)
            }
        }

        static var displayableTabTypes: [TabContent] {
            // Add new displayable types here
            let displayableTypes = [TabContent.anyPreferencePane, .bookmarks]

            return displayableTypes.sorted { first, second in
                guard let firstTitle = first.title, let secondTitle = second.title else {
                    return true // Arbitrary sort order, only non-standard tabs are displayable.
                }
                return firstTitle.localizedStandardCompare(secondTitle) == .orderedAscending
            }
        }

        /// Convenience accessor for `.preferences` Tab Content with no particular pane selected,
        /// i.e. the currently selected pane is decided internally by `PreferencesViewController`.
        static let anyPreferencePane: Self = .preferences(pane: nil)

        var isDisplayable: Bool {
            switch self {
            case .preferences, .bookmarks:
                return true
            default:
                return false
            }
        }

        func matchesDisplayableTab(_ other: TabContent) -> Bool {
            switch (self, other) {
            case (.preferences, .preferences):
                return true
            case (.bookmarks, .bookmarks):
                return true
            default:
                return false
            }
        }

        var title: String? {
            switch self {
            case .url, .homePage, .privatePlayer, .none: return nil
            case .preferences: return UserText.tabPreferencesTitle
            case .bookmarks: return UserText.tabBookmarksTitle
            case .onboarding: return UserText.tabOnboardingTitle
            }
        }

        var url: URL? {
            switch self {
            case .url(let url, userEntered: _):
                return url
            case .privatePlayer(let videoID, let timestamp):
                return .privatePlayer(videoID, timestamp: timestamp)
            default:
                return nil
            }
        }

        var isUrl: Bool {
            switch self {
            case .url, .privatePlayer:
                return true
            default:
                return false
            }
        }

        var isUserEnteredUrl: Bool {
            switch self {
            case .url(_, userEntered: let userEntered):
                return userEntered
            default:
                return false
            }
        }

        var isPrivatePlayer: Bool {
            switch self {
            case .privatePlayer:
                return true
            default:
                return false
            }
        }
    }
    private struct ExtensionDependencies: TabExtensionDependencies {
        let privacyFeatures: PrivacyFeaturesProtocol
        let historyCoordinating: HistoryCoordinating

        var downloadManager: FileDownloadManagerProtocol
    }

    fileprivate weak var delegate: TabDelegate?
    func setDelegate(_ delegate: TabDelegate) { self.delegate = delegate }

    private let navigationDelegate = DistributedNavigationDelegate(logger: .navigation)

    private let cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?
    private let statisticsLoader: StatisticsLoader?
    private let internalUserDecider: InternalUserDeciding?
    let pinnedTabsManager: PinnedTabsManager
    private let privatePlayer: PrivatePlayer
    private let privacyFeatures: AnyPrivacyFeatures
    private var contentBlocking: AnyContentBlocking { privacyFeatures.contentBlocking }

    private let webViewConfiguration: WKWebViewConfiguration

    private var extensions: TabExtensions
    // accesing TabExtensions‘ Public Protocols projecting tab.extensions.extensionName to tab.extensionName
    // allows extending Tab functionality while maintaining encapsulation
    subscript<Extension>(dynamicMember keyPath: KeyPath<TabExtensions, Extension?>) -> Extension? {
        self.extensions[keyPath: keyPath]
    }

    @Published
    private(set) var userContentController: UserContentController?

    convenience init(content: TabContent,
                     faviconManagement: FaviconManagement = FaviconManager.shared,
                     webCacheManager: WebCacheManager = WebCacheManager.shared,
                     webViewConfiguration: WKWebViewConfiguration? = nil,
                     historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
                     pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager,
                     privacyFeatures: AnyPrivacyFeatures? = nil,
                     privatePlayer: PrivatePlayer? = nil,
                     downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
                     cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter? = ContentBlockingAssetsCompilationTimeReporter.shared,
                     statisticsLoader: StatisticsLoader? = nil,
                     extensionsBuilder: TabExtensionsBuilderProtocol = TabExtensionsBuilder.default,
                     localHistory: Set<String> = Set<String>(),
                     title: String? = nil,
                     favicon: NSImage? = nil,
                     interactionStateData: Data? = nil,
                     parentTab: Tab? = nil,
                     shouldLoadInBackground: Bool = false,
                     shouldLoadFromCache: Bool = false,
                     canBeClosedWithBack: Bool = false,
                     lastSelectedAt: Date? = nil,
                     webViewFrame: CGRect = .zero
    ) {

        let privatePlayer = privatePlayer
            ?? (NSApp.isRunningUnitTests ? PrivatePlayer.mock(withMode: .enabled) : PrivatePlayer.shared)
        let statisticsLoader = statisticsLoader
            ?? (NSApp.isRunningUnitTests ? nil : StatisticsLoader.shared)
        let privacyFeatures = privacyFeatures ?? PrivacyFeatures
        let internalUserDecider = (NSApp.delegate as? AppDelegate)?.internalUserDecider

        self.init(content: content,
                  faviconManagement: faviconManagement,
                  webCacheManager: webCacheManager,
                  webViewConfiguration: webViewConfiguration,
                  historyCoordinating: historyCoordinating,
                  pinnedTabsManager: pinnedTabsManager,
                  privacyFeatures: privacyFeatures,
                  privatePlayer: privatePlayer,
                  downloadManager: downloadManager,
                  extensionsBuilder: extensionsBuilder,
                  cbaTimeReporter: cbaTimeReporter,
                  statisticsLoader: statisticsLoader,
                  internalUserDecider: internalUserDecider,
                  localHistory: localHistory,
                  title: title,
                  favicon: favicon,
                  interactionStateData: interactionStateData,
                  parentTab: parentTab,
                  shouldLoadInBackground: shouldLoadInBackground,
                  shouldLoadFromCache: shouldLoadFromCache,
                  canBeClosedWithBack: canBeClosedWithBack,
                  lastSelectedAt: lastSelectedAt,
                  webViewFrame: webViewFrame)
    }

    // swiftlint:disable:next function_body_length
    init(content: TabContent,
         faviconManagement: FaviconManagement,
         webCacheManager: WebCacheManager,
         webViewConfiguration: WKWebViewConfiguration?,
         historyCoordinating: HistoryCoordinating,
         pinnedTabsManager: PinnedTabsManager,
         privacyFeatures: AnyPrivacyFeatures,
         privatePlayer: PrivatePlayer,
         downloadManager: FileDownloadManagerProtocol,
         extensionsBuilder: TabExtensionsBuilderProtocol,
         cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?,
         statisticsLoader: StatisticsLoader?,
         internalUserDecider: InternalUserDeciding?,
         localHistory: Set<String>,
         title: String?,
         favicon: NSImage?,
         interactionStateData: Data?,
         parentTab: Tab?,
         shouldLoadInBackground: Bool,
         shouldLoadFromCache: Bool,
         canBeClosedWithBack: Bool,
         lastSelectedAt: Date?,
         webViewFrame: CGRect
    ) {

        self.content = content
        self.faviconManagement = faviconManagement
        self.historyCoordinating = historyCoordinating
        self.pinnedTabsManager = pinnedTabsManager
        self.privacyFeatures = privacyFeatures
        self.privatePlayer = privatePlayer
        self.cbaTimeReporter = cbaTimeReporter
        self.statisticsLoader = statisticsLoader
        self.internalUserDecider = internalUserDecider
        self.localHistory = localHistory
        self.title = title
        self.favicon = favicon
        self.parentTab = parentTab
        self._canBeClosedWithBack = canBeClosedWithBack
        self.interactionState = interactionStateData.map { .data($0) } ?? (shouldLoadFromCache ? .loadCachedFromTabContent : .none)
        self.lastSelectedAt = lastSelectedAt

        let configuration = webViewConfiguration ?? WKWebViewConfiguration()
        configuration.applyStandardConfiguration(contentBlocking: privacyFeatures.contentBlocking)
        self.webViewConfiguration = configuration
        let userContentController = configuration.userContentController as? UserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController

        webView = WebView(frame: webViewFrame, configuration: configuration)
        webView.allowsLinkPreview = false
        permissions = PermissionModel()

        let userScriptsPublisher = _userContentController.projectedValue
            .compactMap { $0?.$contentBlockingAssets }
            .switchToLatest()
            .map { $0?.userScripts as? UserScripts }
            .eraseToAnyPublisher()

        let userContentControllerPromise = Future<UserContentControllerProtocol, Never>.promise()
        let webViewPromise = Future<WKWebView, Never>.promise()
        self.extensions = extensionsBuilder
            .build(with: (tabIdentifier: instrumentation.currentTabIdentifier,
                          userScriptsPublisher: userScriptsPublisher,
                          inheritedAttribution: parentTab?.adClickAttribution?.currentAttributionState,
                          userContentControllerFuture: userContentControllerPromise.future,
                          webViewFuture: webViewPromise.future,
                          permissionModel: permissions,
                          privacyInfoPublisher: _privacyInfo.projectedValue.eraseToAnyPublisher()),
                   dependencies: ExtensionDependencies(privacyFeatures: privacyFeatures,
                                                       historyCoordinating: historyCoordinating,
                                                       downloadManager: downloadManager))

        super.init()
        userContentController.map(userContentControllerPromise.fulfill)

        setupNavigationDelegate()
        userContentController?.delegate = self
        setupWebView(shouldLoadInBackground: shouldLoadInBackground)
        webViewPromise.fulfill(webView)

        if favicon == nil {
            handleFavicon()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDuckDuckGoEmailSignOut),
                                               name: .emailDidSignOut,
                                               object: nil)
    }

    override func awakeAfter(using decoder: NSCoder) -> Any? {
        for tabExtension in self.extensions {
            (tabExtension as? (any NSCodingExtension))?.awakeAfter(using: decoder)
        }
        return self
    }

    func encodeExtensions(with coder: NSCoder) {
        for tabExtension in self.extensions {
            (tabExtension as? (any NSCodingExtension))?.encode(using: coder)
        }
    }

    func openChild(with content: TabContent, of kind: NewWindowPolicy) {
        guard let delegate else {
            assertionFailure("no delegate set")
            return
        }
        let tab = Tab(content: content, parentTab: self, shouldLoadInBackground: true, canBeClosedWithBack: kind.isSelectedTab)
        delegate.tab(self, createdChild: tab, of: kind)
    }

    @objc func onDuckDuckGoEmailSignOut(_ notification: Notification) {
        guard let url = webView.url else { return }
        if EmailUrls().isDuckDuckGoEmailProtection(url: url) {
            webView.evaluateJavaScript("window.postMessage({ emailProtectionSignedOut: true }, window.origin);")
        }
    }

    deinit {
        cleanUpBeforeClosing()
        webView.configuration.userContentController.removeAllUserScripts()
    }

    func cleanUpBeforeClosing() {
        if content.isUrl, let url = webView.url {
            historyCoordinating.commitChanges(url: url)
        }
        webView.stopLoading()
        webView.stopMediaCapture()
        webView.stopAllMediaPlayback()
        webView.fullscreenWindowController?.close()

        cbaTimeReporter?.tabWillClose(self.instrumentation.currentTabIdentifier)
    }

#if DEBUG
    /// set this to true when Navigation-related decision making is expected to take significant time to avoid assertions
    /// used by BSK: Navigation.DistributedNavigationDelegate
    var shouldDisableLongDecisionMakingChecks: Bool = false
    func disableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = true }
    func enableLongDecisionMakingChecks() { shouldDisableLongDecisionMakingChecks = false }
#else
    func disableLongDecisionMakingChecks() {}
    func enableLongDecisionMakingChecks() {}
#endif

    // MARK: - Event Publishers

    let webViewDidReceiveUserInteractiveChallengePublisher = PassthroughSubject<Void, Never>()
    let webViewDidCommitNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFinishNavigationPublisher = PassthroughSubject<Void, Never>()
    let webViewDidFailNavigationPublisher = PassthroughSubject<Void, Never>()

    @MainActor
    @Published var isAMPProtectionExtracting: Bool = false

    // MARK: - Properties

    let webView: WebView

    private var lastUpgradedURL: URL?

    var contentChangeEnabled = true

    var fbBlockingEnabled = true

    var isLazyLoadingInProgress = false

    @Published private(set) var content: TabContent {
        didSet {
            handleFavicon()
            invalidateInteractionStateData()
            if let oldUrl = oldValue.url {
                historyCoordinating.commitChanges(url: oldUrl)
            }
            error = nil
        }
    }

    func setContent(_ newContent: TabContent) {
        guard contentChangeEnabled else { return }

        let oldContent = self.content
        let newContent: TabContent = {
            if let newContent = privatePlayer.overrideContent(newContent, for: self) {
                return newContent
            }
            if case .preferences(pane: .some) = oldContent,
               case .preferences(pane: nil) = newContent {
                // prevent clearing currently selected pane (for state persistence purposes)
                return oldContent
            }
            return newContent
        }()
        guard newContent != self.content else { return }
        self.content = newContent

        dismissPresentedAlert()

        Task {
            await reloadIfNeeded(shouldLoadInBackground: true)
        }

        if let title = content.title {
            self.title = title
        }
    }

    func setUrl(_ url: URL?, userEntered: Bool) {
        if url == .welcome {
            OnboardingViewModel().restart()
        }
        self.setContent(.contentFromURL(url, userEntered: userEntered))
    }

    private func handleUrlDidChange() {
        if let url = webView.url {
            let content = TabContent.contentFromURL(url)

            if content.isUrl, !webView.isLoading {
                self.addVisit(of: url)
            }
            if content != self.content {
                self.content = content
            }
        }
        self.updateTitle() // The title might not change if webView doesn't think anything is different so update title here as well
    }

    var lastSelectedAt: Date?

    @Published var title: String?

    private func handleTitleDidChange() {
        updateTitle()

        if let title = self.title, let url = webView.url {
            historyCoordinating.updateTitleIfNeeded(title: title, url: url)
        }
    }

    private func updateTitle() {
        var title = webView.title?.trimmingWhitespace()
        if title?.isEmpty ?? true {
            title = webView.url?.host?.droppingWwwPrefix()
        }

        if title != self.title {
            self.title = title
        }
    }

    @PublishedAfter var error: WKError? {
        didSet {
            switch error {
            case .some(URLError.notConnectedToInternet),
                 .some(URLError.networkConnectionLost):
                guard let failingUrl = error?.failingUrl else { break }
                historyCoordinating.markFailedToLoadUrl(failingUrl)
            default:
                break
            }
        }
    }
    let permissions: PermissionModel

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingProgress: Double = 0.0

    /// an Interactive Dialog request (alert/open/save/print) made by a page to be published and presented asynchronously
    @Published
    var userInteractionDialog: UserDialog? {
        didSet {
            guard let request = userInteractionDialog?.request else { return }
            request.addCompletionHandler { [weak self, weak request] _ in
                if let self, let request, self.userInteractionDialog?.request === request {
                    self.userInteractionDialog = nil
                }
            }
        }
    }

    weak private(set) var parentTab: Tab?
    private var _canBeClosedWithBack: Bool
    var canBeClosedWithBack: Bool {
        // Reset canBeClosedWithBack on any WebView navigation
        _canBeClosedWithBack = _canBeClosedWithBack && parentTab != nil && !webView.canGoBack && !webView.canGoForward
        return _canBeClosedWithBack
    }

    private enum InteractionState {
        case none
        case loadCachedFromTabContent
        case data(Data)

        var data: Data? {
            if case .data(let data) = self { return data }
            return nil
        }
        var shouldLoadFromCache: Bool {
            if case .loadCachedFromTabContent = self { return true }
            return false
        }
    }
    private var interactionState: InteractionState

    func invalidateInteractionStateData() {
        interactionState = .none
    }

    func getActualInteractionStateData() -> Data? {
        if let interactionStateData = interactionState.data {
            return interactionStateData
        }

        guard webView.url != nil else { return nil }

        if #available(macOS 12.0, *) {
            self.interactionState = (webView.interactionState as? Data).map { .data($0) } ?? .none
        } else {
            self.interactionState = (try? webView.sessionStateData()).map { .data($0) } ?? .none
        }

        return self.interactionState.data
    }

    private let instrumentation = TabInstrumentation()
    private enum FrameLoadState {
        case provisional
        case committed
        case finished
    }
    private var externalSchemeOpenedPerPageLoad = false

    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var canGoBack: Bool = false

    @MainActor(unsafe)
    private func updateCanGoBackForward(withCurrentNavigation currentNavigation: Navigation? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
        let currentNavigation = currentNavigation ?? navigationDelegate.currentNavigation

        // “freeze” back-forward buttons updates when current backForwardListItem is being popped..
        if webView.backForwardList.currentItem?.identity == currentNavigation?.navigationAction.fromHistoryItemIdentity
            // ..or during the following developer-redirect navigation
            || currentNavigation?.navigationAction.navigationType == .redirect(.developer) {
            return
        }

        let canGoBack = webView.canGoBack || self.error != nil
        let canGoForward = webView.canGoForward && self.error == nil

        if canGoBack != self.canGoBack {
            self.canGoBack = canGoBack
        }
        if canGoForward != self.canGoForward {
            self.canGoForward = canGoForward
        }
    }

    func goBack() {
        guard canGoBack else {
            if canBeClosedWithBack {
                delegate?.closeTab(self)
            }
            return
        }

        guard error == nil else {
            webView.reload()
            return
        }

        shouldStoreNextVisit = false

        // Prevent from a Player reloading loop on back navigation to
        // YT page where the player was enabled (see comment inside)
        if privatePlayer.goBackSkippingLastItemIfNeeded(for: webView) {
            return
        }
        userInteractionDialog = nil
        webView.goBack()
    }

    func goForward() {
        guard canGoForward else { return }
        shouldStoreNextVisit = false
        webView.goForward()
    }

    func go(to item: WKBackForwardListItem) {
        shouldStoreNextVisit = false
        webView.go(to: item)
    }

    func openHomePage() {
        content = .homePage
    }

    func startOnboarding() {
        content = .onboarding
    }

    func reload() {
        userInteractionDialog = nil
        if let error = error, let failingUrl = error.failingUrl {
            webView.load(URLRequest(url: failingUrl, cachePolicy: .reloadIgnoringLocalCacheData))
            return
        }

        if webView.url == nil, content.url != nil {
            // load from cache or interactionStateData when called by lazy loader
            Task { @MainActor [weak self] in
                await self?.reloadIfNeeded(shouldLoadInBackground: true)
            }
        } else if case .privatePlayer = content, let url = content.url {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
    }

    @discardableResult
    private func setFBProtection(enabled: Bool) -> Bool {
        guard self.fbBlockingEnabled != enabled else { return false }
        guard let userContentController = userContentController else {
            assertionFailure("Missing UserContentController")
            return false
        }
        if enabled {
            do {
                try userContentController.enableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("Missing FB List")
                return false
            }
        } else {
            do {
                try userContentController.disableGlobalContentRuleList(withIdentifier: ContentBlockerRulesLists.Constants.clickToLoadRulesListName)
            } catch {
                assertionFailure("FB List was not enabled")
                return false
            }
        }
        self.fbBlockingEnabled = enabled

        return true
    }

    private static let debugEvents = EventMapping<AMPProtectionDebugEvents> { event, _, _, _ in
        switch event {
        case .ampBlockingRulesCompilationFailed:
            Pixel.fire(.ampBlockingRulesCompilationFailed)
        }
    }

    lazy var linkProtection: LinkProtection = {
        LinkProtection(privacyManager: contentBlocking.privacyConfigurationManager,
                       contentBlockingManager: contentBlocking.contentBlockingManager,
                       errorReporting: Self.debugEvents)
    }()

    lazy var referrerTrimming: ReferrerTrimming = {
        ReferrerTrimming(privacyManager: contentBlocking.privacyConfigurationManager,
                         contentBlockingManager: contentBlocking.contentBlockingManager,
                         tld: contentBlocking.tld)
    }()

    @MainActor
    private func reloadIfNeeded(shouldLoadInBackground: Bool = false) async {
        let content = self.content
        guard content.url != nil else { return }

        let url: URL = await {
            if contentURL.isFileURL {
                return contentURL
            }
            return await linkProtection.getCleanURL(from: contentURL, onStartExtracting: {
                isAMPProtectionExtracting = true
            }, onFinishExtracting: { [weak self]
                in self?.isAMPProtectionExtracting = false
            })
        }()
        guard content == self.content else { return }

        if shouldReload(url, shouldLoadInBackground: shouldLoadInBackground) {
            let didRestore = restoreInteractionStateDataIfNeeded()

            if privatePlayer.goBackAndLoadURLIfNeeded(for: self) {
                return
            }

            guard !didRestore else { return }

            if url.isFileURL {
                _ = webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
                return
            }

            var request = URLRequest(url: url, cachePolicy: interactionState.shouldLoadFromCache ? .returnCacheDataElseLoad : .useProtocolCachePolicy)
            if #available(macOS 12.0, *),
               content.isUserEnteredUrl {
                request.attribution = .user
            }
            webView.navigator(distributedNavigationDelegate: navigationDelegate)
                .load(request, withExpectedNavigationType: content.isUserEnteredUrl ? .custom(.userEnteredUrl) : .other)
        }
    }

    @MainActor
    private var contentURL: URL {
        switch content {
        case .url(let value, userEntered: _):
            return value
        case .privatePlayer(let videoID, let timestamp):
            return .privatePlayer(videoID, timestamp: timestamp)
        case .homePage:
            return .homePage
        default:
            return .blankPage
        }
    }

    @MainActor
    private func shouldReload(_ url: URL, shouldLoadInBackground: Bool) -> Bool {
        // don‘t reload in background unless shouldLoadInBackground
        guard url.isValid,
              (webView.superview != nil || shouldLoadInBackground),
              // don‘t reload when already loaded
              webView.url != url,
              webView.url != content.url
        else {
            return false
        }

        if privatePlayer.shouldSkipLoadingURL(for: self) {
            return false
        }

        // if content not loaded inspect error
        switch error {
        case .none, // no error
            // error due to connection failure
             .some(URLError.notConnectedToInternet),
             .some(URLError.networkConnectionLost):
            return true
        case .some:
            // don‘t autoreload on other kinds of errors
            return false
        }
    }

    @MainActor
    private func restoreInteractionStateDataIfNeeded() -> Bool {
        var didRestore: Bool = false
        if let interactionStateData = self.interactionState.data {
            if contentURL.isFileURL {
                _ = webView.loadFileURL(contentURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            }

            if #available(macOS 12.0, *) {
                webView.interactionState = interactionStateData
                didRestore = true
            } else {
                do {
                    try webView.restoreSessionState(from: interactionStateData)
                    didRestore = true
                } catch {
                    os_log("Tab:setupWebView could not restore session state %s", "\(error)")
                }
            }
        }

        return didRestore
    }

    private func addHomePageToWebViewIfNeeded() {
        guard !NSApp.isRunningUnitTests else { return }
        if content == .homePage && webView.url == nil {
            webView.load(URLRequest(url: .homePage))
        }
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func requestFireproofToggle() {
        guard let url = content.url,
              let host = url.host
        else { return }

        _ = FireproofDomains.shared.toggle(domain: host)
    }

    private var webViewCancellables = Set<AnyCancellable>()

    private func setupWebView(shouldLoadInBackground: Bool) {
        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = self
        webView.contextMenuDelegate = self.contextMenuManager
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        permissions.webView = webView

        webViewCancellables.removeAll()

        webView.observe(\.superview, options: .old) { [weak self] _, change in
            // if the webView is being added to superview - reload if needed
            if case .some(.none) = change.oldValue {
                Task { @MainActor [weak self] in
                    await self?.reloadIfNeeded()
                }
            }
        }.store(in: &webViewCancellables)

        webView.observe(\.url) { [weak self] _, _ in
            self?.handleUrlDidChange()
        }.store(in: &webViewCancellables)
        webView.observe(\.title) { [weak self] _, _ in
            self?.handleTitleDidChange()
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoBack) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        webView.observe(\.canGoForward) { [weak self] _, _ in
            self?.updateCanGoBackForward()
        }.store(in: &webViewCancellables)

        webView.publisher(for: \.isLoading)
            .assign(to: \.isLoading, onWeaklyHeld: self)
            .store(in: &webViewCancellables)

        webView.publisher(for: \.estimatedProgress)
            .assign(to: \.loadingProgress, onWeaklyHeld: self)
            .store(in: &webViewCancellables)

        webView.publisher(for: \.serverTrust)
            .sink { [weak self] serverTrust in
                self?.privacyInfo?.serverTrust = serverTrust
            }
            .store(in: &webViewCancellables)

        navigationDelegate.$currentNavigation.sink { [weak self] navigation in
            self?.updateCanGoBackForward(withCurrentNavigation: navigation)
        }.store(in: &webViewCancellables)

        // background tab loading should start immediately
        Task { @MainActor in
            await reloadIfNeeded(shouldLoadInBackground: shouldLoadInBackground)
            if !shouldLoadInBackground {
                addHomePageToWebViewIfNeeded()
            }
        }
    }

    private func dismissPresentedAlert() {
        if let userInteractionDialog {
            switch userInteractionDialog.dialog {
            case .jsDialog: self.userInteractionDialog = nil
            default: break
            }
        }
    }

    // MARK: - Favicon

    @Published var favicon: NSImage?
    let faviconManagement: FaviconManagement

    private func handleFavicon() {
        if content.isPrivatePlayer {
            favicon = .privatePlayer
            return
        }

        guard faviconManagement.areFaviconsLoaded else { return }

        guard content.isUrl, let url = content.url else {
            favicon = nil
            return
        }

        if let cachedFavicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small)?.image {
            if cachedFavicon != favicon {
                favicon = cachedFavicon
            }
        } else {
            favicon = nil
        }
    }

    // MARK: - Global & Local History

    private var historyCoordinating: HistoryCoordinating
    private var shouldStoreNextVisit = true
    private(set) var localHistory: Set<String>

    func addVisit(of url: URL) {
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }

        // Add to global history
        historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host, !host.isEmpty {
            localHistory.insert(host.droppingWwwPrefix())
        }
    }

    // MARK: - Youtube Player

    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?
    private var youtubePlayerCancellables: Set<AnyCancellable> = []

    func setUpYoutubeScriptsIfNeeded() {
        guard privatePlayer.isAvailable else {
            return
        }

        youtubePlayerCancellables.removeAll()

        // only send push updates on macOS 11+ where it's safe to call window.* messages in the browser
        let canPushMessagesToJS: Bool = {
            if #available(macOS 11, *) {
                return true
            } else {
                return false
            }
        }()

        if webView.url?.host?.droppingWwwPrefix() == "youtube.com" && canPushMessagesToJS {
            privatePlayer.$mode
                .dropFirst()
                .sink { [weak self] playerMode in
                    guard let self = self else {
                        return
                    }
                    let userValues = YoutubeOverlayUserScript.UserValues(
                        privatePlayerMode: playerMode,
                        overlayInteracted: self.privatePlayer.overlayInteracted
                    )
                    self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues, inWebView: self.webView)
                }
                .store(in: &youtubePlayerCancellables)
        }

        if url?.isPrivatePlayerScheme == true {
            youtubePlayerScript?.isEnabled = true

            if canPushMessagesToJS {
                privatePlayer.$mode
                    .map { $0 == .enabled }
                    .sink { [weak self] shouldAlwaysOpenPrivatePlayer in
                        guard let self = self else {
                            return
                        }
                        self.youtubePlayerScript?.setAlwaysOpenInPrivatePlayer(shouldAlwaysOpenPrivatePlayer, inWebView: self.webView)
                    }
                    .store(in: &youtubePlayerCancellables)
            }
        } else {
            youtubePlayerScript?.isEnabled = false
        }
    }

    // MARK: - Dashboard Info
    @Published private(set) var privacyInfo: PrivacyInfo?
    private var previousPrivacyInfosByURL: [String: PrivacyInfo] = [:]
    private var didGoBackForward: Bool = false

    private func resetDashboardInfo() {
        if let url = content.url {
            if didGoBackForward, let privacyInfo = previousPrivacyInfosByURL[url.absoluteString] {
                self.privacyInfo = privacyInfo
                didGoBackForward = false
            } else {
                privacyInfo = makePrivacyInfo(url: url)
            }
        } else {
            privacyInfo = nil
        }
    }

    private func makePrivacyInfo(url: URL) -> PrivacyInfo? {
        guard let host = url.host else { return nil }

        let entity = contentBlocking.trackerDataManager.trackerData.findEntity(forHost: host)

        privacyInfo = PrivacyInfo(url: url,
                                  parentEntity: entity,
                                  protectionStatus: makeProtectionStatus(for: host))

        previousPrivacyInfosByURL[url.absoluteString] = privacyInfo

        return privacyInfo
    }

    private func resetConnectionUpgradedTo(navigationAction: NavigationAction) {
        let isOnUpgradedPage = navigationAction.url == privacyInfo?.connectionUpgradedTo
        if navigationAction.isForMainFrame && !isOnUpgradedPage {
            privacyInfo?.connectionUpgradedTo = nil
        }
    }

    public func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        guard let upgradedUrl else { return }
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    private func makeProtectionStatus(for host: String) -> ProtectionStatus {
        let config = contentBlocking.privacyConfigurationManager.privacyConfig

        let isTempUnprotected = config.isTempUnprotected(domain: host)
        let isAllowlisted = config.isUserUnprotected(domain: host)

        var enabledFeatures: [String] = []

        if !config.isInExceptionList(domain: host, forFeature: .contentBlocking) {
            enabledFeatures.append(PrivacyFeature.contentBlocking.rawValue)
        }

        return ProtectionStatus(unprotectedTemporary: isTempUnprotected,
                                enabledFeatures: enabledFeatures,
                                allowlisted: isAllowlisted,
                                denylisted: false)
    }
}

extension Tab: UserContentControllerDelegate {

    func userContentController(_ userContentController: UserContentController, didInstallContentRuleLists contentRuleLists: [String: WKContentRuleList], userScripts: UserScriptsProvider, updateEvent: ContentBlockerRulesManager.UpdateEvent) {
        guard let userScripts = userScripts as? UserScripts else { fatalError("Unexpected UserScripts") }

        userScripts.debugScript.instrumentation = instrumentation
        userScripts.faviconScript.delegate = self
        userScripts.surrogatesScript.delegate = self
        userScripts.contentBlockerRulesScript.delegate = self
        userScripts.clickToLoadScript.delegate = self
        userScripts.pageObserverScript.delegate = self
        userScripts.printingUserScript.delegate = self
        if #available(macOS 11, *) {
            userScripts.autoconsentUserScript?.delegate = self
        }
        youtubeOverlayScript = userScripts.youtubeOverlayScript
        youtubeOverlayScript?.delegate = self
        youtubePlayerScript = userScripts.youtubePlayerUserScript
        setUpYoutubeScriptsIfNeeded()
    }

}

extension Tab: PageObserverUserScriptDelegate {

    func pageDOMLoaded() {
        self.delegate?.tabPageDOMLoaded(self)
    }

}

extension Tab: FaviconUserScriptDelegate {

    func faviconUserScript(_ faviconUserScript: FaviconUserScript,
                           didFindFaviconLinks faviconLinks: [FaviconUserScript.FaviconLink],
                           for documentUrl: URL) {
        faviconManagement.handleFaviconLinks(faviconLinks, documentUrl: documentUrl) { favicon in
            guard documentUrl == self.content.url, let favicon = favicon else {
                return
            }
            self.favicon = favicon.image
        }
    }

}

extension Tab: ContentBlockerRulesUserScriptDelegate {

    func contentBlockerRulesUserScriptShouldProcessTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return true
    }

    func contentBlockerRulesUserScriptShouldProcessCTLTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return fbBlockingEnabled
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedTracker tracker: DetectedRequest) {
        guard let url = URL(string: tracker.pageUrl) else { return }

        privacyInfo?.trackerInfo.addDetectedTracker(tracker, onPageWithURL: url)
        historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        privacyInfo?.trackerInfo.add(detectedThirdPartyRequest: request)
    }

}

extension HistoryCoordinating {

    func addDetectedTracker(_ tracker: DetectedRequest, onURL url: URL) {
        trackerFound(on: url)

        guard tracker.isBlocked,
              let entityName = tracker.entityName else { return }

        addBlockedTracker(entityName: entityName, on: url)
    }

}

extension Tab: ClickToLoadUserScriptDelegate {

    func clickToLoadUserScriptAllowFB(_ script: UserScript, replyHandler: @escaping (Bool) -> Void) {
        guard self.fbBlockingEnabled else {
            replyHandler(true)
            return
        }

        if setFBProtection(enabled: false) {
            replyHandler(true)
        } else {
            replyHandler(false)
        }
    }
}

extension Tab: SurrogatesUserScriptDelegate {
    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
    }

    func surrogatesUserScript(_ script: SurrogatesUserScript, detectedTracker tracker: DetectedRequest, withSurrogate host: String) {
        guard let url = webView.url else { return }

        privacyInfo?.trackerInfo.addInstalledSurrogateHost(host, for: tracker, onPageWithURL: url)
        privacyInfo?.trackerInfo.addDetectedTracker(tracker, onPageWithURL: url)

        historyCoordinating.addDetectedTracker(tracker, onURL: url)
    }
}

extension Tab/*: NavigationResponder*/ { // to be moved to Tab+Navigation.swift

    @MainActor
    func didReceive(_ challenge: URLAuthenticationChallenge, for navigation: Navigation?) async -> AuthChallengeDisposition? {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else { return nil }

        // send this event only when we're interrupting loading and showing extra UI to the user
        webViewDidReceiveUserInteractiveChallengePublisher.send()

        let (request, future) = BasicAuthDialogRequest.future(with: challenge.protectionSpace)
        self.userInteractionDialog = UserDialog(sender: .page(domain: challenge.protectionSpace.host), dialog: .basicAuthenticationChallenge(request))
        do {
            disableLongDecisionMakingChecks()
            defer {
                enableLongDecisionMakingChecks()
            }

            return try await future.get()
        } catch {
            return .cancel
        }
    }

    @MainActor
    func didCommit(_ navigation: Navigation) {
        if content.isUrl, navigation.url == content.url {
            addVisit(of: navigation.url)
        }
        webViewDidCommitNavigationPublisher.send()
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        if let policy = privatePlayer.decidePolicy(for: navigationAction, in: self) {
            return policy
        }

        if navigationAction.url.isFileURL {
            return .allow
        }

        let isLinkActivated = !navigationAction.isTargetingNewWindow
            && (navigationAction.navigationType.isLinkActivated || (navigationAction.navigationType == .other && navigationAction.isUserInitiated))

        let isNavigatingAwayFromPinnedTab: Bool = {
            let isNavigatingToAnotherDomain = navigationAction.url.host != url?.host
            let isPinned = pinnedTabsManager.isTabPinned(self)
            return isLinkActivated && isPinned && isNavigatingToAnotherDomain && navigationAction.isForMainFrame
        }()

        // to be modularized later on, see https://app.asana.com/0/0/1203268245242140/f
        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || navigationAction.navigationType.isMiddleButtonClick || isNavigatingAwayFromPinnedTab
        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !navigationAction.navigationType.isMiddleButtonClick && !NSApp.isCommandPressed)

        didGoBackForward = navigationAction.navigationType.isBackForward

        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
        // which would skip link rewrites.
        if !navigationAction.navigationType.isBackForward {
            let navigationActionPolicy = await linkProtection
                .requestTrackingLinkRewrite(
                    initiatingURL: webView.url,
                    destinationURL: navigationAction.url,
                    onStartExtracting: { if !isRequestingNewTab { isAMPProtectionExtracting = true }},
                    onFinishExtracting: { [weak self] in self?.isAMPProtectionExtracting = false },
                    onLinkRewrite: { [weak self] url in
                        guard let self = self else { return }
                        if isRequestingNewTab || !navigationAction.isForMainFrame {
                            self.openChild(with: .url(url), of: .tab(selected: shouldSelectNewTab || !navigationAction.isForMainFrame))
                        } else {
                            self.webView.load(URLRequest(url: url))
                        }
                    })
            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == false {
                return .cancel
            }
        }

        if navigationAction.isForMainFrame {
            preferences.userAgent = UserAgent.for(navigationAction.url)
        }

        if navigationAction.isForMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }

        if navigationAction.isForMainFrame, !navigationAction.navigationType.isBackForward {
            if let newRequest = referrerTrimming.trimReferrer(for: navigationAction.request, originUrl: navigationAction.sourceFrame.url) {
                if isRequestingNewTab {
                    self.openChild(with: newRequest.url.map { .contentFromURL($0) } ?? .none, of: .tab(selected: shouldSelectNewTab))
                } else {
                    _ = webView.load(newRequest)
                }
                return .cancel
            }
        }

        if navigationAction.isForMainFrame,
           !navigationAction.navigationType.isBackForward,
           !isRequestingNewTab,
           let request = GPCRequestFactory().requestForGPC(basedOn: navigationAction.request,
                                                           config: contentBlocking.privacyConfigurationManager.privacyConfig,
                                                           gpcEnabled: PrivacySecurityPreferences.shared.gpcEnabled) {

            return .redirect(navigationAction, invalidatingBackItemIfNeededFor: webView) {
                $0.load(request)
            }
        }

        self.resetConnectionUpgradedTo(navigationAction: navigationAction)

        if isRequestingNewTab {
            self.openChild(with: .contentFromURL(navigationAction.url), of: .tab(selected: shouldSelectNewTab))
            return .cancel

        }

        guard navigationAction.url.scheme != nil else { return .allow }

        if navigationAction.url.isExternalSchemeLink {
            // request if OS can handle extenrnal url
            self.host(webView.url?.host, requestedOpenExternalURL: navigationAction.url, forUserEnteredURL: navigationAction.isUserEnteredUrl)
            return .cancel
        }

        if navigationAction.isForMainFrame,
           case .success(let upgradedURL) = await privacyFeatures.httpsUpgrade.upgrade(url: navigationAction.url) {

            if lastUpgradedURL != upgradedURL {
                urlDidUpgrade(to: upgradedURL)
                return .redirect(navigationAction, invalidatingBackItemIfNeededFor: webView) {
                    $0.load(URLRequest(url: upgradedURL))
                }
            }
        }

        if !navigationAction.url.isDuckDuckGo {
            await prepareForContentBlocking()
        }

        toggleFBProtection(for: navigationAction.url)

        return .next
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private func host(_ host: String?, requestedOpenExternalURL url: URL, forUserEnteredURL userEnteredUrl: Bool) {
        let searchForExternalUrl = { [weak self] in
            // Redirect after handing WebView.url update after cancelling the request
            DispatchQueue.main.async {
                guard let self, let url = URL.makeSearchUrl(from: url.absoluteString) else { return }
                self.setUrl(url, userEntered: userEnteredUrl)
            }
        }

        guard self.delegate?.tab(self, requestedOpenExternalURL: url, forUserEnteredURL: userEnteredUrl) == true else {
            // search if external URL can‘t be opened but entered by user
            if userEnteredUrl {
                searchForExternalUrl()
            }
            return
        }

        let permissionType = PermissionType.externalScheme(scheme: url.scheme ?? "")

        permissions.permissions([permissionType], requestedForDomain: host, url: url) { [weak self, userEnteredUrl] granted in
            guard granted, let self else {
                // search if denied but entered by user
                if userEnteredUrl {
                    searchForExternalUrl()
                }
                return
            }
            // handle opening extenral URL
            NSWorkspace.shared.open(url)
            self.permissions.permissions[permissionType].externalSchemeOpened()
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private func urlDidUpgrade(to upgradedUrl: URL) {
        lastUpgradedURL = upgradedUrl
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    @MainActor
    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if userContentController?.contentBlockingAssetsInstalled == false
           && contentBlocking.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
            cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)

            disableLongDecisionMakingChecks()
            defer {
                enableLongDecisionMakingChecks()
            }

            await userContentController?.awaitContentBlockingAssetsInstalled()
            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
        } else {
            cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        }
    }

    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = contentBlocking.privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
        setFBProtection(enabled: featureEnabled)
    }

    @MainActor
    func willStart(_ navigation: Navigation) {
        if error != nil { error = nil }

        externalSchemeOpenedPerPageLoad = false
        delegate?.tabWillStartNavigation(self, isUserInitiated: navigation.navigationAction.isUserInitiated)

        if navigation.navigationAction.navigationType.isRedirect {
            resetDashboardInfo()
        }
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        internalUserDecider?.markUserAsInternalIfNeeded(forUrl: webView.url,
                                                        response: navigationResponse.response as? HTTPURLResponse)

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        delegate?.tabDidStartNavigation(self)
        userInteractionDialog = nil

        // Unnecessary assignment triggers publishing
        if error != nil { error = nil }

        invalidateInteractionStateData()
        resetDashboardInfo()
        linkProtection.cancelOngoingExtraction()
        linkProtection.setMainFrameUrl(navigation.url)
        referrerTrimming.onBeginNavigation(to: navigation.url)
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        invalidateInteractionStateData()
        webViewDidFinishNavigationPublisher.send()
        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFinishNavigation()
        setUpYoutubeScriptsIfNeeded()
        statisticsLoader?.refreshRetentionAtb(isSearch: navigation.url.isDuckDuckGoSearch)
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        if navigation.isCurrent {
            self.error = error
        }

        invalidateInteractionStateData()
        linkProtection.setMainFrameUrl(nil)
        referrerTrimming.onFailedNavigation()
        webViewDidFailNavigationPublisher.send()
    }

    func webContentProcessDidTerminate(with reason: WKProcessTerminationReason?) {
        Pixel.fire(.debug(event: .webKitDidTerminate, error: NSError(domain: "WKProcessTerminated", code: reason?.rawValue ?? -1)))
    }

}

@available(macOS 11, *)
extension Tab: AutoconsentUserScriptDelegate {
    func autoconsentUserScript(consentStatus: CookieConsentInfo) {
        self.privacyInfo?.cookieConsentManaged = consentStatus
    }

    func autoconsentUserScriptPromptUserForConsent(_ result: @escaping (Bool) -> Void) {
        delegate?.tab(self, promptUserForCookieConsent: result)
    }
}

extension Tab: YoutubeOverlayUserScriptDelegate {
    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL) {
        let content = Tab.TabContent.contentFromURL(url)
        let isRequestingNewTab = NSApp.isCommandPressed
        if isRequestingNewTab {
            let shouldSelectNewTab = NSApp.isShiftPressed
            self.openChild(with: content, of: .tab(selected: shouldSelectNewTab))
        } else {
            setContent(content)
        }
    }
}

extension Tab: TabDataClearing {
    func prepareForDataClearing(caller: TabDataCleaner) {
        webViewCancellables.removeAll()

        webView.stopLoading()
        webView.configuration.userContentController.removeAllUserScripts()

        webView.navigationDelegate = caller
        webView.load(URLRequest(url: .blankPage))
    }
}

// "protected" properties meant to access otherwise private properties from Tab extensions
extension Tab {

    static var objcDelegateKeyPath: String { #keyPath(objcDelegate) }
    @objc private var objcDelegate: Any? { delegate }

    static var objcNavigationDelegateKeyPath: String { #keyPath(objcNavigationDelegate) }
    @objc private var objcNavigationDelegate: Any? { navigationDelegate }

}
