//
//  AddressBarButtonsViewController.swift
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

import AppKit
import BrowserServicesKit
import Cocoa
import Combine
import Common
import Lottie
import os.log
import PrivacyDashboard
import PixelKit

protocol AddressBarButtonsViewControllerDelegate: AnyObject {

    func addressBarButtonsViewControllerCancelButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController)
    func addressBarButtonsViewController(_ controller: AddressBarButtonsViewController, didUpdateAIChatButtonVisibility isVisible: Bool)
    func addressBarButtonsViewControllerHideAIChatButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController)
}

final class AddressBarButtonsViewController: NSViewController {
    weak var delegate: AddressBarButtonsViewControllerDelegate?

    private let accessibilityPreferences: AccessibilityPreferences
    private let visualStyle: VisualStyleProviding
    private let featureFlagger: FeatureFlagger

    private var permissionAuthorizationPopover: PermissionAuthorizationPopover?
    private func permissionAuthorizationPopoverCreatingIfNeeded() -> PermissionAuthorizationPopover {
        return permissionAuthorizationPopover ?? {
            let popover = PermissionAuthorizationPopover()
            NotificationCenter.default.addObserver(self, selector: #selector(popoverDidClose), name: NSPopover.didCloseNotification, object: popover)
            self.permissionAuthorizationPopover = popover
            popover.setAccessibilityIdentifier("AddressBarButtonsViewController.permissionAuthorizationPopover")
            return popover
        }()
    }

    private var popupBlockedPopover: PopupBlockedPopover?
    private func popupBlockedPopoverCreatingIfNeeded() -> PopupBlockedPopover {
        return popupBlockedPopover ?? {
            let popover = PopupBlockedPopover()
            popover.delegate = self
            self.popupBlockedPopover = popover
            return popover
        }()
    }

    @IBOutlet weak var zoomButton: AddressBarButton!
    @IBOutlet weak var privacyEntryPointButton: MouseOverAnimationButton!
    @IBOutlet weak var separator: NSView!
    @IBOutlet weak var bookmarkButton: AddressBarButton!
    @IBOutlet weak var imageButtonWrapper: NSView!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet private weak var buttonsContainer: NSStackView!
    @IBOutlet weak var aiChatButton: AddressBarMenuButton!

    @IBOutlet weak var animationWrapperView: NSView!
    var trackerAnimationView1: LottieAnimationView!
    var trackerAnimationView2: LottieAnimationView!
    var trackerAnimationView3: LottieAnimationView!
    var shieldAnimationView: LottieAnimationView!
    var shieldDotAnimationView: LottieAnimationView!
    @IBOutlet weak var privacyShieldLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var animationWrapperViewLeadingConstraint: NSLayoutConstraint!

    @IBOutlet weak var aiChatDivider: NSImageView!
    @IBOutlet weak var aiChatStackTrailingViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var notificationAnimationView: NavigationBarBadgeAnimationView!
    @IBOutlet weak var bookmarkButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var bookmarkButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var aiChatButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var aiChatButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var privacyShieldButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var privacyShieldButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageButtonLeadingConstraint: NSLayoutConstraint!

    @IBOutlet private weak var permissionButtons: NSView!
    @IBOutlet weak var cameraButton: PermissionButton! {
        didSet {
            cameraButton.isHidden = true
            cameraButton.target = self
            cameraButton.action = #selector(cameraButtonAction(_:))
        }
    }
    @IBOutlet weak var microphoneButton: PermissionButton! {
        didSet {
            microphoneButton.isHidden = true
            microphoneButton.target = self
            microphoneButton.action = #selector(microphoneButtonAction(_:))
        }
    }
    @IBOutlet weak var geolocationButton: PermissionButton! {
        didSet {
            geolocationButton.isHidden = true
            geolocationButton.target = self
            geolocationButton.action = #selector(geolocationButtonAction(_:))
        }
    }
    @IBOutlet weak var popupsButton: PermissionButton! {
        didSet {
            popupsButton.isHidden = true
            popupsButton.target = self
            popupsButton.action = #selector(popupsButtonAction(_:))
        }
    }
    @IBOutlet weak var externalSchemeButton: PermissionButton! {
        didSet {
            externalSchemeButton.isHidden = true
            externalSchemeButton.target = self
            externalSchemeButton.action = #selector(externalSchemeButtonAction(_:))
        }
    }

    @Published private(set) var buttonsWidth: CGFloat = 0

    private let onboardingPixelReporter: OnboardingAddressBarReporting

    private var tabCollectionViewModel: TabCollectionViewModel
    private var tabViewModel: TabViewModel? {
        didSet {
            popovers?.closeZoomPopover()
            subscribeToTabZoomLevel()
        }
    }

    private let popovers: NavigationBarPopovers?

    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    var controllerMode: AddressBarViewController.Mode? {
        didSet {
            updateButtons()
        }
    }
    var isTextFieldEditorFirstResponder = false {
        didSet {
            updateButtons()
            stopHighlightingPrivacyShield()
        }
    }
    var textFieldValue: AddressBarTextField.Value? {
        didSet {
            updateButtons()
        }
    }
    var isMouseOverNavigationBar = false {
        didSet {
            if isMouseOverNavigationBar != oldValue {
                updateBookmarkButtonVisibility()
            }
        }
    }

    var shouldShowDaxLogInAddressBar: Bool {
        self.tabViewModel?.tab.content == .newtab && visualStyle.addressBarStyleProvider.shouldShowNewSearchIcon
    }

    private var cancellables = Set<AnyCancellable>()
    private var urlCancellable: AnyCancellable?
    private var zoomLevelCancellable: AnyCancellable?
    private var permissionsCancellables = Set<AnyCancellable>()
    private var trackerAnimationTriggerCancellable: AnyCancellable?
    private var privacyEntryPointIconUpdateCancellable: AnyCancellable?

    private lazy var buttonsBadgeAnimator = {
        let animator = NavigationBarBadgeAnimator()
        animator.delegate = self
        return animator
    }()

    private var hasPrivacyInfoPulseQueuedAnimation = false

    required init?(coder: NSCoder) {
        fatalError("AddressBarButtonsViewController: Bad initializer")
    }

    private let aiChatTabOpener: AIChatTabOpening
    private let aiChatMenuConfig: AIChatMenuVisibilityConfigurable
    private let aiChatSidebarPresenter: AIChatSidebarPresenting

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          accessibilityPreferences: AccessibilityPreferences = AccessibilityPreferences.shared,
          popovers: NavigationBarPopovers?,
          onboardingPixelReporter: OnboardingAddressBarReporting = OnboardingPixelReporter(),
          aiChatTabOpener: AIChatTabOpening,
          aiChatMenuConfig: AIChatMenuVisibilityConfigurable,
          aiChatSidebarPresenter: AIChatSidebarPresenting,
          visualStyleManager: VisualStyleManagerProviding = NSApp.delegateTyped.visualStyleManager,
          featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.accessibilityPreferences = accessibilityPreferences
        self.popovers = popovers
        self.onboardingPixelReporter = onboardingPixelReporter
        self.aiChatTabOpener = aiChatTabOpener
        self.aiChatMenuConfig = aiChatMenuConfig
        self.aiChatSidebarPresenter = aiChatSidebarPresenter
        self.visualStyle = visualStyleManager.style
        self.featureFlagger = featureFlagger
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAnimationViews()
        setupNotificationAnimationView()
        subscribeToSelectedTabViewModel()
        subscribeToBookmarkList()
        subscribeToEffectiveAppearance()
        subscribeToIsMouseOverAnimationVisible()
        updateBookmarkButtonVisibility()
        subscribeToPrivacyEntryPointIsMouseOver()
        subscribeToButtonsVisibility()
        subscribeToAIChatPreferences()
        setupButtonsCornerRadius()
        setupButtonsSize()

        bookmarkButton.sendAction(on: .leftMouseDown)
        bookmarkButton.normalTintColor = visualStyle.colorsProvider.iconsColor
        configureAIChatButton()
        privacyEntryPointButton.toolTip = UserText.privacyDashboardTooltip
        setupButtonPaddings()
    }

    func setupButtonPaddings(isFocused: Bool = false) {
        guard visualStyle.addressBarStyleProvider.shouldAddPaddingToAddressBarButtons else { return }

        imageButtonLeadingConstraint.constant = isFocused ? 2 : 1
        animationWrapperViewLeadingConstraint.constant = 1

        if let superview = privacyEntryPointButton.superview {
            privacyEntryPointButton.translatesAutoresizingMaskIntoConstraints = false
            privacyShieldLeadingConstraint.constant = isFocused ? 4 : 3
            NSLayoutConstraint.activate([
                privacyEntryPointButton.topAnchor.constraint(equalTo: superview.topAnchor, constant: 2),
                privacyEntryPointButton.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -2)
            ])
        }

        if let superview = aiChatButton.superview {
            aiChatButton.translatesAutoresizingMaskIntoConstraints = false
            aiChatStackTrailingViewConstraint.constant = isFocused ? 4 : 3
            NSLayoutConstraint.activate([
                aiChatButton.topAnchor.constraint(equalTo: superview.topAnchor, constant: 2),
                aiChatButton.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -2)
            ])
        }
    }

    override func viewWillAppear() {
        setupButtons()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        // The permission popover leaks when its parent window is closed while it's still visible, so this workaround
        // forces it to deallocate when the window is closing. This workaround can be removed if the true source of
        // the leak is found.
        if let permissionAuthorizationPopover, permissionAuthorizationPopover.isShown {
            permissionAuthorizationPopover.close()
        }
    }

    func showBadgeNotification(_ type: NavigationBarBadgeAnimationView.AnimationType) {
        if !isAnyShieldAnimationPlaying {
            buttonsBadgeAnimator.showNotification(withType: type,
                                                  buttonsContainer: buttonsContainer,
                                                  notificationBadgeContainer: notificationAnimationView)
        } else {
            buttonsBadgeAnimator.queuedAnimation = NavigationBarBadgeAnimator.QueueData(selectedTab: tabViewModel?.tab,
                                                                                        animationType: type)
        }
    }

    private func playBadgeAnimationIfNecessary() {
        if let queuedNotification = buttonsBadgeAnimator.queuedAnimation {
            // Add small time gap in between animations if badge animation was queued
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if self.tabViewModel?.tab == queuedNotification.selectedTab {
                    self.showBadgeNotification(queuedNotification.animationType)
                } else {
                    self.buttonsBadgeAnimator.queuedAnimation = nil
                }
            }
        }
    }

    private func playPrivacyInfoHighlightAnimationIfNecessary() {
        if hasPrivacyInfoPulseQueuedAnimation {
            hasPrivacyInfoPulseQueuedAnimation = false
            // Give a bit of delay to have a better animation effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                ViewHighlighter.highlight(view: self.privacyEntryPointButton, inParent: self.view)
            }
        }
    }

    var mouseEnterExitTrackingArea: NSTrackingArea?

    override func viewDidLayout() {
        super.viewDidLayout()
        if view.window?.isPopUpWindow == false {
            updateTrackingAreaForHover()
        }
        self.buttonsWidth = buttonsContainer.frame.size.width + 10.0
    }

    func updateTrackingAreaForHover() {
        if let previous = mouseEnterExitTrackingArea {
            view.removeTrackingArea(previous)
        }
        let trackingArea = NSTrackingArea(rect: view.frame, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: view, userInfo: nil)
        view.addTrackingArea(trackingArea)
        mouseEnterExitTrackingArea = trackingArea
    }

    @IBAction func bookmarkButtonAction(_ sender: Any) {
        openBookmarkPopover(setFavorite: false, accessPoint: .button)
    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        delegate?.addressBarButtonsViewControllerCancelButtonClicked(self)
    }

    @IBAction func privacyEntryPointButtonAction(_ sender: Any) {
        openPrivacyDashboardPopover()
    }

    @IBAction func aiChatButtonAction(_ sender: Any) {
        PixelKit.fire(AIChatPixel.aiChatAddressBarButtonClicked, frequency: .dailyAndCount, includeAppVersionParameter: true)

        let isCommandPressed = NSEvent.modifierFlags.contains(.command)
        let isShiftPressed = NSApplication.shared.isShiftPressed

        var target: AIChatTabOpenerTarget = .sameTab

        if isCommandPressed {
            target = isShiftPressed ? .newTabSelected : .newTabUnselected
        }

        if let tabViewModel = tabViewModel,
           let tabURL = tabViewModel.tab.url,
           !tabURL.isDuckAIURL,
           tabViewModel.tab.content != .newtab {
            target = .newTabSelected
        }

        if featureFlagger.isFeatureOn(.aiChatSidebar), case .url = tabViewModel?.tabContent, !isTextFieldEditorFirstResponder {
            aiChatSidebarPresenter.toggleSidebar()
        } else if let value = textFieldValue {
            aiChatTabOpener.openAIChatTab(value, target: target)
        } else {
            aiChatTabOpener.openAIChatTab(nil, target: target)
        }
    }

    func openPrivacyDashboardPopover(entryPoint: PrivacyDashboardEntryPoint = .dashboard) {
        if let permissionAuthorizationPopover, permissionAuthorizationPopover.isShown {
            permissionAuthorizationPopover.close()
        }
        popupBlockedPopover?.close()

        popovers?.togglePrivacyDashboardPopover(for: tabViewModel, from: privacyEntryPointButton, entryPoint: entryPoint)
        onboardingPixelReporter.measurePrivacyDashboardOpened()
    }

    private func setupButtonsCornerRadius() {
        let cornerRadius = visualStyle.addressBarStyleProvider.addressBarButtonsCornerRadius
        aiChatButton.setCornerRadius(cornerRadius)
        bookmarkButton.setCornerRadius(cornerRadius)
        cancelButton.setCornerRadius(cornerRadius)
        permissionButtons.setCornerRadius(cornerRadius)
        zoomButton.setCornerRadius(cornerRadius)
        privacyEntryPointButton.setCornerRadius(cornerRadius)
    }

    private func setupButtonsSize() {
        bookmarkButtonWidthConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
        bookmarkButtonHeightConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
        aiChatButtonWidthConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
        aiChatButtonHeightConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
        privacyShieldButtonWidthConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
        privacyShieldButtonHeightConstraint.constant = visualStyle.addressBarStyleProvider.addressBarButtonSize
    }

    private func updateBookmarkButtonVisibility() {
        guard view.window?.isPopUpWindow == false else { return }
        bookmarkButton.setAccessibilityIdentifier("AddressBarButtonsViewController.bookmarkButton")
        let hasEmptyAddressBar = textFieldValue?.isEmpty ?? true
        var shouldShowBookmarkButton: Bool {
            guard let tabViewModel, tabViewModel.canBeBookmarked else { return false }

            var isUrlBookmarked = false
            if let url = tabViewModel.tab.content.userEditableUrl {
                let urlVariants = url.bookmarkButtonUrlVariants()

                // Check if any of the URL variants is bookmarked
                isUrlBookmarked = urlVariants.contains { variant in
                    return bookmarkManager.isUrlBookmarked(url: variant)
                }
            }

            return cancelButton.isHidden && !hasEmptyAddressBar && (isMouseOverNavigationBar || popovers?.isEditBookmarkPopoverShown == true || isUrlBookmarked)
        }

        bookmarkButton.isShown = shouldShowBookmarkButton
        updateAIChatDividerVisibility()
    }

    private func updateZoomButtonVisibility(animation: Bool = false) {
        let hasURL = tabViewModel?.tab.url != nil
        let isEditingMode = controllerMode?.isEditing ?? false
        let isTextFieldValueText = textFieldValue?.isText ?? false

        enum ZoomState { case zoomedIn, zoomedOut }
        var zoomState: ZoomState?
        if let zoomLevel = tabViewModel?.zoomLevel, zoomLevel != accessibilityPreferences.defaultPageZoom {
            zoomState = (zoomLevel > accessibilityPreferences.defaultPageZoom) ? .zoomedIn : .zoomedOut
        }

        let isPopoverShown = popovers?.isZoomPopoverShown == true
        let shouldShowZoom = hasURL
        && !isEditingMode
        && !isTextFieldValueText
        && !isTextFieldEditorFirstResponder
        && !animation
        && (zoomState != .none || isPopoverShown)

        zoomButton.image = (zoomState == .zoomedOut) ? visualStyle.iconsProvider.moreOptionsMenuIconsProvider.zoomOutIcon : visualStyle.iconsProvider.moreOptionsMenuIconsProvider.zoomInIcon
        zoomButton.backgroundColor = isPopoverShown ? .buttonMouseDown : nil
        zoomButton.mouseOverColor = isPopoverShown ? nil : .buttonMouseOver
        zoomButton.isHidden = !shouldShowZoom
        zoomButton.normalTintColor = visualStyle.colorsProvider.iconsColor
    }

    // Temporarily hide/display AI chat button (does not persist)
    func updateAIChatButtonVisibility(isHidden: Bool) {
        aiChatButton.isHidden = isHidden
        updateAIChatDividerVisibility()
        delegate?.addressBarButtonsViewController(self, didUpdateAIChatButtonVisibility: aiChatButton.isShown)
    }

    private func updateAIChatButtonVisibility() {
        aiChatButton.toolTip = isTextFieldEditorFirstResponder ? UserText.aiChatAddressBarShortcutTooltip : UserText.aiChatAddressBarTooltip

        let isPopUpWindow = view.window?.isPopUpWindow ?? false
        aiChatButton.isHidden = !aiChatMenuConfig.shouldDisplayAddressBarShortcut || isPopUpWindow
        updateAIChatDividerVisibility()
        delegate?.addressBarButtonsViewController(self, didUpdateAIChatButtonVisibility: aiChatButton.isShown)

        // Check if the current tab is in the onboarding state and disable the AI chat button if it is
        guard let tabViewModel else { return }
        let isOnboarding = [.onboarding].contains(tabViewModel.tab.content)
        aiChatButton.isEnabled = !isOnboarding
    }

    @objc func hideAIChatButtonAction(_ sender: NSMenuItem) {
        delegate?.addressBarButtonsViewControllerHideAIChatButtonClicked(self)
    }

    private func updateAIChatDividerVisibility() {
        let shouldShowDivider = cancelButton.isShown || bookmarkButton.isShown
        aiChatDivider.isHidden = aiChatButton.isHidden || !shouldShowDivider
    }

    private func updateButtonsPosition() {
        aiChatButton.position = .right
        bookmarkButton.position = aiChatButton.isShown ? .center : .right
    }

    func openBookmarkPopover(setFavorite: Bool, accessPoint: GeneralPixel.AccessPoint) {
        guard let popovers else {
            return
        }
        let result = bookmarkForCurrentUrl(setFavorite: setFavorite, accessPoint: accessPoint)
        guard let bookmark = result.bookmark else {
            assertionFailure("Failed to get a bookmark for the popover")
            return
        }

        if popovers.isEditBookmarkPopoverShown {
            updateBookmarkButtonVisibility()
            popovers.closeEditBookmarkPopover()
        } else {
            popovers.showEditBookmarkPopover(with: bookmark, isNew: result.isNew, from: bookmarkButton, withDelegate: self)
        }
    }

    func openPermissionAuthorizationPopover(for query: PermissionAuthorizationQuery) {
        let button: PermissionButton

        lazy var popover: NSPopover = {
            let popover = self.permissionAuthorizationPopoverCreatingIfNeeded()
            popover.behavior = .applicationDefined
            return popover
        }()

        if query.permissions.contains(.camera)
            || (query.permissions.contains(.microphone) && microphoneButton.isHidden && cameraButton.isShown) {
            button = cameraButton
        } else {
            assert(query.permissions.count == 1)
            switch query.permissions.first {
            case .microphone:
                button = microphoneButton
            case .geolocation:
                button = geolocationButton
            case .popups:
                guard !query.wasShownOnce else { return }
                button = popupsButton
                popover = popupBlockedPopoverCreatingIfNeeded()
            case .externalScheme:
                button = externalSchemeButton
                query.shouldShowAlwaysAllowCheckbox = true
                query.shouldShowCancelInsteadOfDeny = true
            default:
                assertionFailure("Unexpected permissions")
                query.handleDecision(grant: false)
                return
            }
        }
        guard button.isVisible else { return }

        button.backgroundColor = .buttonMouseDown
        button.mouseOverColor = .buttonMouseDown
        (popover.contentViewController as? PermissionAuthorizationViewController)?.query = query

        DispatchQueue.main.asyncAfter(deadline: .now() + NSAnimationContext.current.duration) {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            query.wasShownOnce = true
        }
    }

    func closePrivacyDashboard() {
        popovers?.closePrivacyDashboard()
    }

    func openPrivacyDashboard() {
        guard let tabViewModel else { return }
        popovers?.openPrivacyDashboard(for: tabViewModel, from: privacyEntryPointButton, entryPoint: .dashboard)
    }

    func openZoomPopover(source: ZoomPopover.Source) {
        guard let popovers,
              let tabViewModel = tabCollectionViewModel.selectedTabViewModel else { return }

        if let zoomPopover = popovers.zoomPopover, zoomPopover.isShown {
            // reschedule close timer for already shown popover
            zoomPopover.rescheduleCloseTimerIfNeeded()
            return
        }

        zoomButton.isShown = true
        popovers.showZoomPopover(for: tabViewModel, from: zoomButton, addressBar: parent?.view, withDelegate: self, source: source)
        updateZoomButtonVisibility()
    }

    func updateButtons() {
        stopAnimationsAfterFocus()

        cancelButton.isShown = isTextFieldEditorFirstResponder && !textFieldValue.isEmpty

        updateImageButton()
        updatePrivacyEntryPointButton()
        updatePermissionButtons()
        updateBookmarkButtonVisibility()
        updateZoomButtonVisibility()
        updateAIChatButtonVisibility()
        updateButtonsPosition()
    }

    @IBAction func zoomButtonAction(_ sender: Any) {
        guard let popovers else { return }
        if popovers.isZoomPopoverShown {
            popovers.closeZoomPopover()
        } else {
            openZoomPopover(source: .toolbar)
        }
    }

    @IBAction func cameraButtonAction(_ sender: NSButton) {
        guard let tabViewModel else {
            assertionFailure("No selectedTabViewModel")
            return
        }
        if case .requested(let query) = tabViewModel.usedPermissions.camera {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        var permissions = Permissions()
        permissions.camera = tabViewModel.usedPermissions.camera
        if microphoneButton.isHidden {
            permissions.microphone = tabViewModel.usedPermissions.microphone
        }

        let url = tabViewModel.tab.content.urlForWebView ?? .empty
        let domain = url.isFileURL ? .localhost : (url.host ?? "")

        PermissionContextMenu(permissions: permissions.map { ($0, $1) }, domain: domain, delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func microphoneButtonAction(_ sender: NSButton) {
        guard let tabViewModel,
              let state = tabViewModel.usedPermissions.microphone
        else {
            Logger.general.error("Selected tab view model is nil or no microphone state")
            return
        }
        if case .requested(let query) = state {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        let url = tabViewModel.tab.content.urlForWebView ?? .empty
        let domain = url.isFileURL ? .localhost : (url.host ?? "")

        PermissionContextMenu(permissions: [(.microphone, state)], domain: domain, delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func geolocationButtonAction(_ sender: NSButton) {
        guard let tabViewModel,
              let state = tabViewModel.usedPermissions.geolocation
        else {
            Logger.general.error("Selected tab view model is nil or no geolocation state")
            return
        }
        if case .requested(let query) = state {
            openPermissionAuthorizationPopover(for: query)
            return
        }

        let url = tabViewModel.tab.content.urlForWebView ?? .empty
        let domain = url.isFileURL ? .localhost : (url.host ?? "")

        PermissionContextMenu(permissions: [(.geolocation, state)], domain: domain, delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func popupsButtonAction(_ sender: NSButton) {
        guard let tabViewModel,
              let state = tabViewModel.usedPermissions.popups
        else {
            Logger.general.error("Selected tab view model is nil or no popups state")
            return
        }

        let permissions: [(PermissionType, PermissionState)]
        let domain: String
        if case .requested(let query) = state {
            domain = query.domain
            permissions = tabViewModel.tab.permissions.authorizationQueries.reduce(into: .init()) {
                guard $1.permissions.contains(.popups) else { return }
                $0.append( (.popups, .requested($1)) )
            }
        } else {
            let url = tabViewModel.tab.content.urlForWebView ?? .empty
            domain = url.isFileURL ? .localhost : (url.host ?? "")
            permissions = [(.popups, state)]
        }
        PermissionContextMenu(permissions: permissions, domain: domain, delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @IBAction func externalSchemeButtonAction(_ sender: NSButton) {
        guard let tabViewModel,
              let (permissionType, state) = tabViewModel.usedPermissions.first(where: { $0.key.isExternalScheme })
        else {
            Logger.general.error("Selected tab view model is nil or no externalScheme state")
            return
        }

        let permissions: [(PermissionType, PermissionState)]
        if case .requested(let query) = state {
            query.wasShownOnce = false
            openPermissionAuthorizationPopover(for: query)
            return
        }

        permissions = [(permissionType, state)]
        let url = tabViewModel.tab.content.urlForWebView ?? .empty
        let domain = url.isFileURL ? .localhost : (url.host ?? "")

        PermissionContextMenu(permissions: permissions, domain: domain, delegate: self)
            .popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    private func setupButtons() {
        if view.window?.isPopUpWindow == true {
            privacyEntryPointButton.position = .free
            cameraButton.position = .free
            geolocationButton.position = .free
            popupsButton.position = .free
            microphoneButton.position = .free
            externalSchemeButton.position = .free
            bookmarkButton.isHidden = true
        } else {
            bookmarkButton.position = .right
            privacyEntryPointButton.position = .left
        }

        privacyEntryPointButton.sendAction(on: .leftMouseUp)

        (imageButton.cell as? NSButtonCell)?.highlightsBy = NSCell.StyleMask(rawValue: 0)

        cameraButton.sendAction(on: .leftMouseDown)
        microphoneButton.sendAction(on: .leftMouseDown)
        geolocationButton.sendAction(on: .leftMouseDown)
        popupsButton.sendAction(on: .leftMouseDown)
        externalSchemeButton.sendAction(on: .leftMouseDown)
    }

    private var animationViewCache = [String: LottieAnimationView]()
    private func getAnimationView(for animationName: String) -> LottieAnimationView? {
        if let animationView = animationViewCache[animationName] {
            return animationView
        }

        guard let animationView = LottieAnimationView(named: animationName,
                                                      imageProvider: trackerAnimationImageProvider) else {
            assertionFailure("Missing animation file")
            return nil
        }

        animationViewCache[animationName] = animationView
        return animationView
    }

    private func setupNotificationAnimationView() {
        notificationAnimationView.alphaValue = 0.0
    }

    private func setupAnimationViews() {

        func addAndLayoutAnimationViewIfNeeded(animationView: LottieAnimationView?,
                                               animationName: String,
                                               // Default use of .mainThread to prevent high WindowServer Usage
                                               // Pending Fix with newer Lottie versions
                                               // https://app.asana.com/0/1177771139624306/1207024603216659/f
                                               renderingEngine: Lottie.RenderingEngineOption = .mainThread) -> LottieAnimationView {
            if let animationView = animationView, animationView.identifier?.rawValue == animationName {
                return animationView
            }

            animationView?.removeFromSuperview()

            let newAnimationView: LottieAnimationView
            // For unknown reason, this caused infinite execution of various unit tests.
            if AppVersion.runType.requiresEnvironment {
                newAnimationView = getAnimationView(for: animationName) ?? LottieAnimationView()
            } else {
                newAnimationView = LottieAnimationView()
            }
            newAnimationView.configuration = LottieConfiguration(renderingEngine: renderingEngine)
            animationWrapperView.addAndLayout(newAnimationView)
            newAnimationView.isHidden = true
            return newAnimationView
        }

        let isAquaMode = NSApp.effectiveAppearance.name == .aqua
        let style = visualStyle.addressBarStyleProvider.privacyShieldStyleProvider

        trackerAnimationView1 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView1,
                                                                  animationName: isAquaMode ? "trackers-1" : "dark-trackers-1",
                                                                  renderingEngine: .mainThread)
        trackerAnimationView2 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView2,
                                                                  animationName: isAquaMode ? "trackers-2" : "dark-trackers-2",
                                                                  renderingEngine: .mainThread)
        trackerAnimationView3 = addAndLayoutAnimationViewIfNeeded(animationView: trackerAnimationView3,
                                                                  animationName: isAquaMode ? "trackers-3" : "dark-trackers-3",
                                                                  renderingEngine: .mainThread)
        shieldAnimationView = addAndLayoutAnimationViewIfNeeded(animationView: shieldAnimationView,
                                                                animationName: style.animationForShield(forLightMode: isAquaMode))
        shieldDotAnimationView = addAndLayoutAnimationViewIfNeeded(animationView: shieldDotAnimationView,
                                                                   animationName: style.animationForShieldWithDot(forLightMode: isAquaMode))
    }

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel.sink { [weak self] tabViewModel in
            guard let self else { return }

            stopAnimations()
            closePrivacyDashboard()

            self.tabViewModel = tabViewModel
            subscribeToUrl()
            subscribeToPermissions()
            subscribeToPrivacyEntryPointIconUpdateTrigger()

            updatePrivacyEntryPointIcon()
        }.store(in: &cancellables)
    }

    private func subscribeToUrl() {
        guard let tabViewModel else {
            urlCancellable = nil
            return
        }
        urlCancellable = tabViewModel.tab.$content
            .combineLatest(tabViewModel.tab.$error)
            .sink { [weak self] _ in
                guard let self else { return }

                stopAnimations()
                updateBookmarkButtonImage()
                updateButtons()
                subscribeToTrackerAnimationTrigger()
            }
    }

    private func subscribeToPermissions() {
        permissionsCancellables.removeAll(keepingCapacity: true)

        tabViewModel?.$usedPermissions.dropFirst().sink { [weak self] _ in
            self?.updatePermissionButtons()
        }.store(in: &permissionsCancellables)
        tabViewModel?.$permissionAuthorizationQuery.dropFirst().sink { [weak self] _ in
            self?.updatePermissionButtons()
        }.store(in: &permissionsCancellables)
    }

    private func subscribeToTrackerAnimationTrigger() {
        trackerAnimationTriggerCancellable = tabViewModel?.trackersAnimationTriggerPublisher
            .first()
            .sink { [weak self] _ in
                self?.animateTrackers()
            }
    }

    private func subscribeToPrivacyEntryPointIconUpdateTrigger() {
        privacyEntryPointIconUpdateCancellable = tabViewModel?.privacyEntryPointIconUpdateTrigger
            .sink { [weak self] _ in
                self?.updatePrivacyEntryPointIcon()
            }
    }

    private func subscribeToBookmarkList() {
        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            updateBookmarkButtonImage()
            updateBookmarkButtonVisibility()
        }.store(in: &cancellables)
    }

    // update Separator on Privacy Entry Point and other buttons appearance change
    private func subscribeToButtonsVisibility() {
        privacyEntryPointButton.publisher(for: \.isHidden).asVoid()
            .merge(with: permissionButtons.publisher(for: \.frame).asVoid())
            .merge(with: zoomButton.publisher(for: \.isHidden).asVoid())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateSeparator()
            }
            .store(in: &cancellables)
    }

    private func subscribeToAIChatPreferences() {
        aiChatMenuConfig.valuesChangedPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in
                self?.updateAIChatButtonVisibility()
            }).store(in: &cancellables)
    }

    private func configureAIChatButton() {
        aiChatButton.image = visualStyle.iconsProvider.navigationToolbarIconsProvider.aiChatButtonImage
        aiChatButton.mouseOverColor = visualStyle.colorsProvider.buttonMouseOverColor
        aiChatButton.normalTintColor = visualStyle.colorsProvider.iconsColor
        aiChatButton.setAccessibilityIdentifier("AddressBarButtonsViewController.aiChatButton")
        aiChatButton.menu = NSMenu {
            NSMenuItem(title: UserText.aiChatAddressBarHideButton,
                       action: #selector(hideAIChatButtonAction(_:)),
                       keyEquivalent: "")
        }
    }

    private func updatePermissionButtons() {
        guard let tabViewModel else { return }

        permissionButtons.isShown = !isTextFieldEditorFirstResponder
        && !isAnyTrackerAnimationPlaying
        && !tabViewModel.isShowingErrorPage
        defer {
            showOrHidePermissionPopoverIfNeeded()
        }

        geolocationButton.buttonState = tabViewModel.usedPermissions.geolocation

        let (camera, microphone) = PermissionState?.combineCamera(tabViewModel.usedPermissions.camera,
                                                                  withMicrophone: tabViewModel.usedPermissions.microphone)
        cameraButton.buttonState = camera
        microphoneButton.buttonState = microphone

        popupsButton.buttonState = tabViewModel.usedPermissions.popups?.isRequested == true // show only when there're popups blocked
        ? tabViewModel.usedPermissions.popups
        : nil
        externalSchemeButton.buttonState = tabViewModel.usedPermissions.externalScheme

        geolocationButton.normalTintColor = visualStyle.colorsProvider.iconsColor
        cameraButton.normalTintColor = visualStyle.colorsProvider.iconsColor
        microphoneButton.normalTintColor = visualStyle.colorsProvider.iconsColor
    }

    private func showOrHidePermissionPopoverIfNeeded() {
        guard let tabViewModel else { return }

        for permission in tabViewModel.usedPermissions.keys {
            guard case .requested(let query) = tabViewModel.usedPermissions[permission] else { continue }
            let permissionAuthorizationPopover = permissionAuthorizationPopoverCreatingIfNeeded()
            guard !permissionAuthorizationPopover.isShown else {
                if permissionAuthorizationPopover.viewController.query === query { return }
                permissionAuthorizationPopover.close()
                return
            }
            openPermissionAuthorizationPopover(for: query)
            return
        }
        if let permissionAuthorizationPopover, permissionAuthorizationPopover.isShown {
            permissionAuthorizationPopover.close()
        }

    }

    private func updateBookmarkButtonImage(isUrlBookmarked: Bool = false) {
        if let url = tabViewModel?.tab.content.userEditableUrl,
           isUrlBookmarked || bookmarkManager.isAnyUrlVariantBookmarked(url: url)
        {
            bookmarkButton.image = visualStyle.iconsProvider.bookmarksIconsProvider.bookmarkFilledIcon
            bookmarkButton.mouseOverTintColor = NSColor.bookmarkFilledTint
            bookmarkButton.toolTip = UserText.editBookmarkTooltip
            bookmarkButton.setAccessibilityValue("Bookmarked")
        } else {
            bookmarkButton.mouseOverTintColor = nil
            bookmarkButton.image = visualStyle.iconsProvider.bookmarksIconsProvider.bookmarkIcon
            bookmarkButton.contentTintColor = visualStyle.colorsProvider.iconsColor
            bookmarkButton.toolTip = ShortcutTooltip.bookmarkThisPage.value
            bookmarkButton.setAccessibilityValue("Unbookmarked")
        }
    }

    private func updateImageButton() {
        guard let tabViewModel else { return }

        imageButton.contentTintColor = visualStyle.colorsProvider.iconsColor

        switch controllerMode {
        case .browsing where tabViewModel.isShowingErrorPage:
            imageButton.image = .web
        case .browsing:
            if let favicon = tabViewModel.favicon {
                imageButton.image = favicon
            } else if isTextFieldEditorFirstResponder {
                imageButton.image = .web
            }
        case .editing(.url):
            imageButton.image = .web
        case .editing(.text):
            if visualStyle.addressBarStyleProvider.shouldShowNewSearchIcon {
                imageButton.image = visualStyle.addressBarStyleProvider.addressBarLogoImage
            } else {
                imageButton.image = .search
            }
        case .editing(.openTabSuggestion):
            imageButton.image = .openTabSuggestion
        default:
            imageButton.image = nil
        }
    }

    private func updatePrivacyEntryPointButton() {
        guard let tabViewModel else { return }

        let url = tabViewModel.tab.content.userEditableUrl
        let isNewTabOrOnboarding = [.newtab, .onboarding].contains(tabViewModel.tab.content)
        let isHypertextUrl = url?.navigationalScheme?.isHypertextScheme == true && url?.isDuckPlayer == false
        let isEditingMode = controllerMode?.isEditing ?? false
        let isTextFieldValueText = textFieldValue?.isText ?? false
        let isLocalUrl = url?.isLocalURL ?? false

        // Privacy entry point button
        let isFlaggedAsMalicious = (tabViewModel.tab.privacyInfo?.malicousSiteThreatKind != .none)
        privacyEntryPointButton.isAnimationEnabled = !isFlaggedAsMalicious
        privacyEntryPointButton.normalTintColor = isFlaggedAsMalicious ? .fireButtonRedPressed : .privacyEnabled
        privacyEntryPointButton.mouseOverTintColor = isFlaggedAsMalicious ? .alertRedHover : privacyEntryPointButton.mouseOverTintColor
        privacyEntryPointButton.mouseDownTintColor = isFlaggedAsMalicious ? .alertRedPressed : privacyEntryPointButton.mouseDownTintColor

        privacyEntryPointButton.isShown = !isEditingMode
        && !isTextFieldEditorFirstResponder
        && isHypertextUrl
        && !tabViewModel.isShowingErrorPage
        && !isTextFieldValueText
        && !isLocalUrl

        imageButtonWrapper.isShown = imageButton.image != nil
        && view.window?.isPopUpWindow != true
        && (isHypertextUrl || isTextFieldEditorFirstResponder || isEditingMode || isNewTabOrOnboarding)
        && privacyEntryPointButton.isHidden
        && !isAnyTrackerAnimationPlaying
    }

    private func updatePrivacyEntryPointIcon() {
        let privacyShieldStyle = visualStyle.addressBarStyleProvider.privacyShieldStyleProvider
        guard AppVersion.runType.requiresEnvironment else { return }
        privacyEntryPointButton.image = nil

        guard let tabViewModel else { return }
        guard !isAnyShieldAnimationPlaying else { return }

        switch tabViewModel.tab.content {
        case .url(let url, _, _), .identityTheftRestoration(let url), .subscription(let url):
            guard let host = url.host else { break }

            let isNotSecure = url.scheme == URL.NavigationalScheme.http.rawValue
            let isCertificateInvalid = tabViewModel.tab.isCertificateInvalid
            let isFlaggedAsMalicious = (tabViewModel.tab.privacyInfo?.malicousSiteThreatKind != .none)
            let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
            let isUnprotected = configuration.isUserUnprotected(domain: host)

            let isShieldDotVisible = isNotSecure || isUnprotected || isCertificateInvalid

            if isFlaggedAsMalicious {
                privacyEntryPointButton.isAnimationEnabled = false
                privacyEntryPointButton.image = .redAlertCircle16
                privacyEntryPointButton.normalTintColor = .alertRed
                privacyEntryPointButton.mouseOverTintColor = .alertRedHover
                privacyEntryPointButton.mouseDownTintColor = .alertRedPressed
            } else {
                privacyEntryPointButton.image = isShieldDotVisible ? privacyShieldStyle.iconWithDot : privacyShieldStyle.icon
                privacyEntryPointButton.isAnimationEnabled = true

                let animationNames = MouseOverAnimationButton.AnimationNames(
                    aqua: isShieldDotVisible ? privacyShieldStyle.hoverAnimationWithDot(forLightMode: true) : privacyShieldStyle.hoverAnimation(forLightMode: true),
                    dark: isShieldDotVisible ? privacyShieldStyle.hoverAnimationWithDot(forLightMode: false) : privacyShieldStyle.hoverAnimation(forLightMode: false)
                )
                privacyEntryPointButton.animationNames = animationNames
            }
        default:
            break
        }
    }

    private func updateSeparator() {
        separator.isShown = privacyEntryPointButton.isVisible && (
            (permissionButtons.subviews.contains(where: { $0.isVisible })) || zoomButton.isVisible
        )
    }

    // MARK: Tracker Animation

    let trackerAnimationImageProvider = TrackerAnimationImageProvider()

    private func animateTrackers() {
        guard privacyEntryPointButton.isShown, let tabViewModel else { return }

        switch tabViewModel.tab.content {
        case .url(let url, _, _):
            // Don't play the shield animation if mouse is over
            guard !privacyEntryPointButton.isAnimationViewVisible else {
                break
            }

            var animationView: LottieAnimationView
            if url.navigationalScheme == .http {
                animationView = shieldDotAnimationView
            } else {
                animationView = shieldAnimationView
            }

            animationView.isHidden = false
            updateZoomButtonVisibility(animation: true)
            animationView.play { [weak self] _ in
                animationView.isHidden = true
                self?.updateZoomButtonVisibility(animation: false)
            }
        default:
            return
        }

        if let trackerInfo = tabViewModel.tab.privacyInfo?.trackerInfo {
            let lastTrackerImages = PrivacyIconViewModel.trackerImages(from: trackerInfo)
            trackerAnimationImageProvider.lastTrackerImages = lastTrackerImages

            let trackerAnimationView: LottieAnimationView?
            switch lastTrackerImages.count {
            case 0: trackerAnimationView = nil
            case 1: trackerAnimationView = trackerAnimationView1
            case 2: trackerAnimationView = trackerAnimationView2
            default: trackerAnimationView = trackerAnimationView3
            }
            trackerAnimationView?.isHidden = false
            trackerAnimationView?.reloadImages()
            self.updateZoomButtonVisibility(animation: true)
            trackerAnimationView?.play { [weak self] _ in
                trackerAnimationView?.isHidden = true
                guard let self else { return }
                updatePrivacyEntryPointIcon()
                updatePermissionButtons()
                // If badge animation is not queueued check if we should animate the privacy shield
                if buttonsBadgeAnimator.queuedAnimation == nil {
                    playPrivacyInfoHighlightAnimationIfNecessary()
                }
                playBadgeAnimationIfNecessary()
                updateZoomButtonVisibility(animation: false)
            }
        }

        updatePrivacyEntryPointIcon()
        updatePermissionButtons()
    }

    private func stopAnimations(trackerAnimations: Bool = true,
                                shieldAnimations: Bool = true,
                                badgeAnimations: Bool = true) {
        func stopAnimation(_ animationView: LottieAnimationView) {
            if animationView.isAnimationPlaying || animationView.isShown {
                animationView.isHidden = true
                animationView.stop()
            }
        }

        if trackerAnimations {
            stopAnimation(trackerAnimationView1)
            stopAnimation(trackerAnimationView2)
            stopAnimation(trackerAnimationView3)
        }
        if shieldAnimations {
            stopAnimation(shieldAnimationView)
            stopAnimation(shieldDotAnimationView)
        }
        if badgeAnimations {
            stopNotificationBadgeAnimations()
        }
    }

    private func stopNotificationBadgeAnimations() {
        notificationAnimationView.removeAnimation()
        buttonsBadgeAnimator.queuedAnimation = nil
    }

    private var isAnyTrackerAnimationPlaying: Bool {
        trackerAnimationView1.isAnimationPlaying ||
        trackerAnimationView2.isAnimationPlaying ||
        trackerAnimationView3.isAnimationPlaying
    }

    private var isAnyShieldAnimationPlaying: Bool {
        shieldAnimationView.isAnimationPlaying ||
        shieldDotAnimationView.isAnimationPlaying
    }

    private func stopAnimationsAfterFocus() {
        if isTextFieldEditorFirstResponder {
            stopAnimations()
        }
    }

    private func bookmarkForCurrentUrl(setFavorite: Bool, accessPoint: GeneralPixel.AccessPoint) -> (bookmark: Bookmark?, isNew: Bool) {
        guard let tabViewModel,
              let url = tabViewModel.tab.content.userEditableUrl else {
            assertionFailure("No URL for bookmarking")
            return (nil, false)
        }

        if let bookmark = bookmarkManager.getBookmark(forVariantUrl: url) {
            if setFavorite {
                bookmark.isFavorite = true
                bookmarkManager.update(bookmark: bookmark)
            }

            return (bookmark, false)
        }

        let lastUsedFolder = UserDefaultsBookmarkFoldersStore().lastBookmarkSingleTabFolderIdUsed.flatMap(bookmarkManager.getBookmarkFolder)
        let bookmark = bookmarkManager.makeBookmark(for: url,
                                                    title: tabViewModel.title,
                                                    isFavorite: setFavorite,
                                                    index: nil,
                                                    parent: lastUsedFolder)
        updateBookmarkButtonImage(isUrlBookmarked: bookmark != nil)

        return (bookmark, true)
    }

    private func subscribeToEffectiveAppearance() {
        NSApp.publisher(for: \.effectiveAppearance)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupAnimationViews()
                self?.updatePrivacyEntryPointIcon()
                self?.updateZoomButtonVisibility()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabZoomLevel() {
        zoomLevelCancellable = tabViewModel?.zoomLevelSubject
            .sink { [weak self] _ in
                self?.updateZoomButtonVisibility()
            }
    }

    private func subscribeToIsMouseOverAnimationVisible() {
        privacyEntryPointButton.$isAnimationViewVisible
            .dropFirst()
            .sink { [weak self] isAnimationViewVisible in

                if isAnimationViewVisible {
                    self?.stopAnimations(trackerAnimations: false, shieldAnimations: true, badgeAnimations: false)
                } else {
                    self?.updatePrivacyEntryPointIcon()
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToPrivacyEntryPointIsMouseOver() {
        privacyEntryPointButton.publisher(for: \.isMouseOver)
            .first(where: { $0 }) // only interested when mouse is over
            .sink(receiveValue: { [weak self] _ in
                self?.stopHighlightingPrivacyShield()
            })
            .store(in: &cancellables)
    }

}

// MARK: - Contextual Onboarding View Highlight

extension AddressBarButtonsViewController {

    func highlightPrivacyShield() {
        if !isAnyShieldAnimationPlaying && buttonsBadgeAnimator.queuedAnimation == nil {
            ViewHighlighter.highlight(view: privacyEntryPointButton, inParent: self.view)
        } else {
            hasPrivacyInfoPulseQueuedAnimation = true
        }
    }

    func stopHighlightingPrivacyShield() {
        hasPrivacyInfoPulseQueuedAnimation = false
        ViewHighlighter.stopHighlighting(view: privacyEntryPointButton)
    }

}

// MARK: - NavigationBarBadgeAnimatorDelegate

extension AddressBarButtonsViewController: NavigationBarBadgeAnimatorDelegate {

    func didFinishAnimating() {
        playPrivacyInfoHighlightAnimationIfNecessary()
    }

}

// MARK: - PermissionContextMenuDelegate

extension AddressBarButtonsViewController: PermissionContextMenuDelegate {

    func permissionContextMenu(_ menu: PermissionContextMenu, mutePermissions permissions: [PermissionType]) {
        tabViewModel?.tab.permissions.set(permissions, muted: true)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, unmutePermissions permissions: [PermissionType]) {
        tabViewModel?.tab.permissions.set(permissions, muted: false)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, allowPermissionQuery query: PermissionAuthorizationQuery) {
        tabViewModel?.tab.permissions.allow(query)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysAllowPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.allow, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, alwaysDenyPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.deny, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenu(_ menu: PermissionContextMenu, resetStoredPermission permission: PermissionType) {
        PermissionManager.shared.setPermission(.ask, forDomain: menu.domain, permissionType: permission)
    }
    func permissionContextMenuReloadPage(_ menu: PermissionContextMenu) {
        tabViewModel?.reload()
    }

}

// MARK: - NSPopoverDelegate

extension AddressBarButtonsViewController: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        guard let popovers, let popover = notification.object as? NSPopover else { return }

        switch popover {
        case popovers.bookmarkPopover:
            if popovers.bookmarkPopover?.isNew == true {
                NotificationCenter.default.post(name: .bookmarkPromptShouldShow, object: nil)
            }
            updateBookmarkButtonVisibility()
        case popovers.zoomPopover:
            updateZoomButtonVisibility()
        case is PermissionAuthorizationPopover,
            is PopupBlockedPopover:
            if let button = popover.positioningView as? PermissionButton {
                button.backgroundColor = .clear
                button.mouseOverColor = .buttonMouseOver
            } else {
                assertionFailure("Unexpected popover positioningView: \(popover.positioningView?.description ?? "<nil>"), expected PermissionButton")
            }
        default:
            break
        }
    }

}

// MARK: - AnimationImageProvider

final class TrackerAnimationImageProvider: AnimationImageProvider {

    var lastTrackerImages = [CGImage]()

    func imageForAsset(asset: ImageAsset) -> CGImage? {
        switch asset.name {
        case "img_0.png": return lastTrackerImages[safe: 0]
        case "img_1.png": return lastTrackerImages[safe: 1]
        case "img_2.png": return lastTrackerImages[safe: 2]
        case "img_3.png": return lastTrackerImages[safe: 3]
        default: return nil
        }
    }

}

// MARK: - URL Helpers

extension URL {
    private static let localPatterns = [
        "^localhost$",
        "^::1$",
        "^.+\\.local$",
        "^localhost\\.localhost$",
        "^127\\.0\\.0\\.1$",
        "^10\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)$",
        "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)$",
        "^192\\.168\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)$",
        "^169\\.254\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)$",
        "^fc[0-9a-fA-F]{2}:.+",
        "^fe80:.+"
    ]

    private static var compiledRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []
        for pattern in localPatterns {
            if let newRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                regexes.append(newRegex)
            }
        }
        return regexes
    }()

    var isLocalURL: Bool {
        if let host = self.host {
            for regex in Self.compiledRegexes
            where regex.firstMatch(in: host, options: [], range: host.fullRange) != nil {
                return true
            }
        }
        return false
    }
}
