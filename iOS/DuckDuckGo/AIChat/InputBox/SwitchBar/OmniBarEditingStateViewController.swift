//
//  OmniBarEditingStateViewController.swift
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

import UIKit
import DesignResourcesKit
import Combine
import BrowserServicesKit
import Bookmarks
import Persistence
import History
import Core
import Suggestions
import SwiftUI

struct SuggestionTrayDependencies {
    let favoritesViewModel: FavoritesListInteracting
    let bookmarksDatabase: CoreDataDatabase
    let historyManager: HistoryManaging
    let tabsModel: TabsModel
    let featureFlagger: FeatureFlagger
    let appSettings: AppSettings
}

protocol OmniBarEditingStateViewControllerDelegate: AnyObject {
    func onQueryUpdated(_ query: String)
    func onQuerySubmitted(_ query: String)
    func onPromptSubmitted(_ query: String)
    func onSelectFavorite(_ favorite: BookmarkEntity)
    func onSelectSuggestion(_ suggestion: Suggestion)
}

/// Later: Inject auto suggestions here.
final class OmniBarEditingStateViewController: UIViewController {

    private enum ViewVisibility {
        case visible
        case hidden
    }

    var textAreaView: UIView {
        switchBarVC.textEntryViewController.textEntryView
    }
    private var cancellables = Set<AnyCancellable>()
    private let switchBarHandler: SwitchBarHandling
    private lazy var switchBarVC = SwitchBarViewController(switchBarHandler: switchBarHandler)
    weak var delegate: OmniBarEditingStateViewControllerDelegate?
    private var suggestionTrayViewController: SuggestionTrayViewController?
    private var daxLogoHostingController: UIHostingController<NewTabPageDaxLogoView>?
    var expectedStartFrame: CGRect?
    var suggestionTrayDependencies: SuggestionTrayDependencies?
    lazy var isTopBarPosition = AppDependencyProvider.shared.appSettings.currentAddressBarPosition == .top
    private var topSwitchBarConstraint: NSLayoutConstraint?

    internal init(switchBarHandler: any SwitchBarHandling) {
        self.switchBarHandler = switchBarHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        installSwitchBarVC()
        installSuggestionsTray()
        installDaxLogoView()

        self.view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        animateAppearance()
    }

    private func animateAppearance() {

        guard let expectedStartFrame else {
            self.switchBarVC.setExpanded(true)
            return
        }

        // Prepare initial state
        let heightConstraint = switchBarVC.view.heightAnchor.constraint(equalToConstant: expectedStartFrame.height)
        if isTopBarPosition {
            heightConstraint.isActive = true
            topPositionAppearance(expectedStartFrame: expectedStartFrame, heightConstraint: heightConstraint)
        } else {
            bottomPositionAppearance()
        }

    }

    private func topPositionAppearance(expectedStartFrame: CGRect, heightConstraint: NSLayoutConstraint) {
        topSwitchBarConstraint = switchBarVC.view.topAnchor.constraint(equalTo: view.topAnchor, constant: expectedStartFrame.minY)
        topSwitchBarConstraint?.isActive = true
        self.switchBarVC.setExpanded(false)
        self.switchBarVC.view.alpha = 0.0

        self.view.layoutIfNeeded()

        // Create animators
        let backgroundFadeAnimator = UIViewPropertyAnimator(duration: 0.15, curve: .easeIn) {
            self.view.backgroundColor = UIColor(designSystemColor: .background)
        }

        let fadeInAnimator = UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) {
            self.switchBarVC.view.alpha = 1.0
        }

        let expandAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.7) {
            self.switchBarVC.setExpanded(true)
            heightConstraint.isActive = false

            self.switchBarVC.view.layoutIfNeeded()
        }

        // Schedule animations
        backgroundFadeAnimator.addCompletion { _ in
            expandAnimator.startAnimation()
            self.switchBarVC.focusTextField()
        }

        // Start animations
        backgroundFadeAnimator.startAnimation()
        fadeInAnimator.startAnimation()
    }

    private func bottomPositionAppearance() {

        topSwitchBarConstraint = switchBarVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80)
        topSwitchBarConstraint?.isActive = true
        self.switchBarVC.setExpanded(true)
        self.switchBarVC.view.alpha = 0.0

        self.view.layoutIfNeeded()

        // Create animators
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.75) {
            self.view.backgroundColor = UIColor(designSystemColor: .background)
            self.switchBarVC.view.alpha = 1.0
            self.topSwitchBarConstraint?.constant = 20

            self.view.layoutIfNeeded()
        }

        // Schedule animations
        animator.addCompletion { _ in
            self.switchBarVC.focusTextField()
        }

        // Start animations
        animator.startAnimation()
    }

    @objc private func dismissButtonTapped(_ sender: UIButton) {
        switchBarVC.unfocusTextField()
        setSuggestionTrayVisibility(.hidden)
        setLogoVisibility(.hidden)

        dismissAnimated()
    }

    @objc func dismissAnimated(_ completion: (() -> Void)? = nil) {
        animateDismissal {
            DispatchQueue.main.async {
                if self.presentingViewController != nil {
                    self.dismiss(animated: false)
                }
                completion?()
            }
        }
    }

    private func animateDismissal(_ completion: (() -> Void)? = nil) {

        self.view.layoutIfNeeded()

        if isTopBarPosition {
            topPositionDismissal(completion)
        } else {
            bottomPositionDismissal(completion)
        }
    }

    private func topPositionDismissal(_ completion: (() -> Void)?) {
        // Create animators
        let collapseAnimator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.7) {
            self.switchBarVC.setExpanded(false)
            if let expectedStartFrame = self.expectedStartFrame {
                let heightConstraint = self.switchBarVC.view.heightAnchor.constraint(equalToConstant: expectedStartFrame.height)
                heightConstraint.isActive = true
            }

            self.view.layoutIfNeeded()
        }

        let backgroundFadeAnimator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
            self.view.backgroundColor = .clear
        }

        let fadeOutAnimator = UIViewPropertyAnimator(duration: 0.15, curve: .easeIn) {
            self.switchBarVC.view.alpha = 0.0
        }

        fadeOutAnimator.addCompletion { _ in
            completion?()
        }

        // Start animations
        collapseAnimator.startAnimation()
        backgroundFadeAnimator.startAnimation()
        fadeOutAnimator.startAnimation()
    }

    private func bottomPositionDismissal(_ completion: (() -> Void)?) {
        let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
            self.view.backgroundColor = .clear
            self.switchBarVC.view.alpha = 0.0
            self.topSwitchBarConstraint?.constant = 80

            self.view.layoutIfNeeded()
        }

        animator.addCompletion { _ in
            completion?()
        }

        animator.startAnimation()
    }

    private func installSwitchBarVC() {
        addChild(switchBarVC)
        view.addSubview(switchBarVC.view)
        switchBarVC.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            switchBarVC.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            switchBarVC.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])

        switchBarVC.didMove(toParent: self)

        switchBarVC.backButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        setupSubscriptions()
    }

    private func handleQueryUpdate(_ query: String) {
        handleSuggestionTrayWithQuery(query)
    }

    private func setupSubscriptions() {
        switchBarHandler.currentTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentText in
                self?.delegate?.onQueryUpdated(currentText)
                self?.handleQueryUpdate(currentText)
            }
            .store(in: &cancellables)

        switchBarHandler.toggleStatePublisher
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] newState in
                guard let self = self else { return }
                switch newState {
                case .search:
                    if self.switchBarHandler.currentText.isEmpty {
                        self.showSuggestionTray(.favorites)
                    } else {
                        self.showSuggestionTray(.autocomplete(query: self.switchBarHandler.currentText))
                    }
                case .aiChat:
                    self.setSuggestionTrayVisibility(.hidden)
                    self.setLogoVisibility(.visible)
                }
            }
            .store(in: &cancellables)

        switchBarHandler.textSubmissionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] submission in
                switch submission.mode {
                case .search:
                    self?.delegate?.onQuerySubmitted(submission.text)
                case .aiChat:
                    self?.delegate?.onPromptSubmitted(submission.text)
                }

                self?.switchBarHandler.clearText()
            }
            .store(in: &cancellables)

    }

    func selectAllText() {
        switchBarVC.textEntryViewController.selectAllText()
    }

    private func installDaxLogoView() {
        let daxLogoView = NewTabPageDaxLogoView()
        let hostingController = UIHostingController(rootView: daxLogoView)
        daxLogoHostingController = hostingController
        
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        /// Offset so the logo is displayed on the same height as the NTP logo
        let logoOffset: CGFloat = 18
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: logoOffset),
        ])
        
        hostingController.didMove(toParent: self)
        
        view.sendSubviewToBack(hostingController.view)
    }
}

extension OmniBarEditingStateViewController: AutocompleteViewControllerDelegate {
    func autocompleteDidEndWithUserQuery() {

    }

    func autocomplete(selectedSuggestion suggestion: Suggestion) {
        delegate?.onSelectSuggestion(suggestion)
    }

    func autocomplete(highlighted suggestion: Suggestion, for query: String) {

    }

    func autocomplete(pressedPlusButtonForSuggestion suggestion: Suggestion) {

    }

    func autocompleteWasDismissed() {

    }
}

extension OmniBarEditingStateViewController: FavoritesOverlayDelegate {

    func favoritesOverlay(_ overlay: FavoritesOverlay, didSelect favorite: BookmarkEntity) {
        delegate?.onSelectFavorite(favorite)
    }
}

// MARK: - Suggestion Tray methods

extension OmniBarEditingStateViewController {
    private func handleSuggestionTrayWithQuery(_ query: String) {
        guard switchBarHandler.currentToggleState == .search else { return }

        if query.isEmpty {
            showSuggestionTray(.favorites)
        } else {
            showSuggestionTray(.autocomplete(query: query))
        }
    }

    private func showSuggestionTray(_ type: SuggestionTrayViewController.SuggestionType) {
        guard switchBarHandler.currentToggleState == .search else { return }

        let canShowSuggestion = suggestionTrayViewController?.canShow(for: type) == true
        suggestionTrayViewController?.view.isHidden = !canShowSuggestion
        daxLogoHostingController?.view.isHidden = canShowSuggestion

        if canShowSuggestion {
            suggestionTrayViewController?.show(for: type)
        }
    }


    private func setSuggestionTrayVisibility(_ visibility: ViewVisibility) {
        suggestionTrayViewController?.view.isHidden = visibility == .hidden
    }

    private func setLogoVisibility(_ visibility: ViewVisibility) {
        daxLogoHostingController?.view.isHidden = visibility == .hidden
    }

    private func installSuggestionsTray() {
        guard let dependencies = suggestionTrayDependencies else { return }
        let storyboard = UIStoryboard(name: "SuggestionTray", bundle: nil)

        guard let controller = storyboard.instantiateInitialViewController(creator: { coder in
            SuggestionTrayViewController(coder: coder,
                                         favoritesViewModel: dependencies.favoritesViewModel,
                                         bookmarksDatabase: dependencies.bookmarksDatabase,
                                         historyManager: dependencies.historyManager,
                                         tabsModel: dependencies.tabsModel,
                                         featureFlagger: dependencies.featureFlagger,
                                         appSettings: dependencies.appSettings)
        }) else {
            assertionFailure()
            return
        }
        addChild(controller)
        view.addSubview(controller.view)
        suggestionTrayViewController = controller
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: switchBarVC.view.bottomAnchor),
        ])

        controller.autocompleteDelegate = self
        controller.favoritesOverlayDelegate = self
        suggestionTrayViewController = controller

        view.bringSubviewToFront(switchBarVC.view)
    }
}
