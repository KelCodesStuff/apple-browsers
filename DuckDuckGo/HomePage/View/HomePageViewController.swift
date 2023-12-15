//
//  HomePageViewController.swift
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
import Combine
import SwiftUI

@MainActor
final class HomePageViewController: NSViewController {

    private let tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager
    private let historyCoordinating: HistoryCoordinating
    private let fireViewModel: FireViewModel
    private let onboardingViewModel: OnboardingViewModel

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    var favoritesModel: HomePage.Models.FavoritesModel!
    var defaultBrowserModel: HomePage.Models.DefaultBrowserModel!
    var recentlyVisitedModel: HomePage.Models.RecentlyVisitedModel!
    var featuresModel: HomePage.Models.ContinueSetUpModel!
    var appearancePreferences: AppearancePreferences!
    var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .defaultBrowserDismissed, defaultValue: false)
    var defaultBrowserDismissed: Bool

    required init?(coder: NSCoder) {
        fatalError("HomePageViewController: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel,
         bookmarkManager: BookmarkManager,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         fireViewModel: FireViewModel? = nil,
         onboardingViewModel: OnboardingViewModel = OnboardingViewModel()) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating
        self.fireViewModel = fireViewModel ?? FireCoordinator.fireViewModel
        self.onboardingViewModel = onboardingViewModel

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        favoritesModel = createFavoritesModel()
        defaultBrowserModel = createDefaultBrowserModel()
        recentlyVisitedModel = createRecentlyVisitedModel()
        featuresModel = createFeatureModel()
        appearancePreferences = AppearancePreferences.shared

        refreshModels()

        let rootView = HomePage.Views.RootView(isBurner: tabCollectionViewModel.isBurner)
            .environmentObject(favoritesModel)
            .environmentObject(defaultBrowserModel)
            .environmentObject(recentlyVisitedModel)
            .environmentObject(featuresModel)
            .environmentObject(appearancePreferences)
            .onTapGesture { [weak self] in
                // Remove focus from the address bar if interacting with this view.
                self?.view.makeMeFirstResponder()
            }

        self.view = NSHostingView(rootView: rootView)
    }

    override func viewDidLoad() {
        refreshModelsOnAppBecomingActive()
        subscribeToBookmarks()
        subscribeToBurningData()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if !PixelExperiment.isExperimentInstalled {
            if onboardingViewModel.onboardingFinished && Pixel.isNewUser {
                Pixel.fire(.newTabInitial(), limitTo: .initial)
            }
        }
        subscribeToHistory()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshModels()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        historyCancellable = nil
    }

    func refreshModelsOnAppBecomingActive() {
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshModels()
            }.store(in: &self.cancellables)
    }

    func refreshModels() {
        guard NSApp.runType.requiresEnvironment else { return }

        refreshFavoritesModel()
        refreshRecentlyVisitedModel()
        refreshDefaultBrowserModel()
        refreshContinueSetUpModel()
    }

    func createRecentlyVisitedModel() -> HomePage.Models.RecentlyVisitedModel {
        return .init { [weak self] url in
            self?.openUrl(url)
        }
    }

    func createFeatureModel() -> HomePage.Models.ContinueSetUpModel {
#if NETWORK_PROTECTION
        let vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            dataImportProvider: BookmarksAndPasswordsImportStatusProvider(),
            tabCollectionViewModel: tabCollectionViewModel,
            duckPlayerPreferences: DuckPlayerPreferencesUserDefaultsPersistor(),
            networkProtectionRemoteMessaging: DefaultNetworkProtectionRemoteMessaging(),
            appGroupUserDefaults: .netP
        )
#else
        let vm = HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            dataImportProvider: BookmarksAndPasswordsImportStatusProvider(),
            tabCollectionViewModel: tabCollectionViewModel,
            duckPlayerPreferences: DuckPlayerPreferencesUserDefaultsPersistor()
        )
#endif

        return vm
    }

    func createDefaultBrowserModel() -> HomePage.Models.DefaultBrowserModel {
        return .init(isDefault: DefaultBrowserPreferences().isDefault, wasClosed: defaultBrowserDismissed, requestSetDefault: { [weak self] in
            let defaultBrowserPreferencesModel = DefaultBrowserPreferences()
            defaultBrowserPreferencesModel.becomeDefault { [weak self] isDefault in
                _ = defaultBrowserPreferencesModel
                self?.defaultBrowserModel.isDefault = isDefault
            }
        }, close: { [weak self] in
            self?.defaultBrowserDismissed = true
            withAnimation {
                self?.defaultBrowserModel.wasClosed = true
            }
        })
    }

    func createFavoritesModel() -> HomePage.Models.FavoritesModel {
        return .init(open: { [weak self] bookmark, target in
            guard let urlObject = bookmark.urlObject else { return }
            self?.openUrl(urlObject, target: target)
        }, removeFavorite: { [weak self] bookmark in
            bookmark.isFavorite = !bookmark.isFavorite
            self?.bookmarkManager.update(bookmark: bookmark)
        }, deleteBookmark: { [weak self] bookmark in
            self?.bookmarkManager.remove(bookmark: bookmark)
        }, addEdit: { [weak self] bookmark in
            self?.showAddEditController(for: bookmark)
        }, moveFavorite: { [weak self] (bookmark, index) in
            self?.bookmarkManager.moveFavorites(with: [bookmark.id], toIndex: index) { _ in }
        }, onFaviconMissing: { [weak self] in
            self?.faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
        })
    }

    func refreshFavoritesModel() {
        favoritesModel.favorites = bookmarkManager.list?.favoriteBookmarks ?? []
    }

    func refreshContinueSetUpModel() {
        featuresModel.refreshFeaturesMatrix()
    }

    func refreshRecentlyVisitedModel() {
        recentlyVisitedModel.refreshWithHistory(historyCoordinating.history ?? [])
    }

    func refreshDefaultBrowserModel() {
        let prefs = DefaultBrowserPreferences()
        if prefs.isDefault {
            defaultBrowserDismissed = false
        }

        defaultBrowserModel.isDefault = prefs.isDefault
        defaultBrowserModel.wasClosed = defaultBrowserDismissed
    }

    func subscribeToBookmarks() {
        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            withAnimation {
                self?.refreshFavoritesModel()
            }
        }.store(in: &cancellables)
    }

    private func openUrl(_ url: URL, target: HomePage.Models.FavoritesModel.OpenTarget? = nil) {
        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
            return
        }

        if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: true)
            return
        }

        if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: false)
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .bookmark))
    }

    private func showAddEditController(for bookmark: Bookmark? = nil) {
        let addEditFavoriteViewController = AddEditFavoriteViewController.create(bookmark: bookmark)

        self.beginSheet(addEditFavoriteViewController)
    }

    private var burningDataCancellable: AnyCancellable?
    private func subscribeToBurningData() {
        burningDataCancellable = fireViewModel.fire.$burningData
            .dropFirst()
            .sink { [weak self] burningData in
                if burningData == nil {
                    self?.refreshModels()
                }
            }
    }

    private var historyCancellable: AnyCancellable?
    private func subscribeToHistory() {
        historyCancellable = historyCoordinating.historyDictionaryPublisher.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshModels()
            }
    }

}
