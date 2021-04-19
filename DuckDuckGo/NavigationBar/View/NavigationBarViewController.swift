//
//  NavigationBarViewController.swift
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
import os.log

final class NavigationBarViewController: NSViewController {

    @IBOutlet weak var goBackButton: NSButton!
    @IBOutlet weak var goForwardButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!

    var addressBarViewController: AddressBarViewController?

    private var tabCollectionViewModel: TabCollectionViewModel

    // swiftlint:disable weak_delegate
    private let goBackButtonMenuDelegate: NavigationButtonMenuDelegate
    private let goForwardButtonMenuDelegate: NavigationButtonMenuDelegate
    // swiftlint:enable weak_delegate

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var navigationButtonsCancellables = Set<AnyCancellable>()

    required init?(coder: NSCoder) {
        fatalError("NavigationBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        goBackButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .back, tabCollectionViewModel: tabCollectionViewModel)
        goForwardButtonMenuDelegate = NavigationButtonMenuDelegate(buttonType: .forward, tabCollectionViewModel: tabCollectionViewModel)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationButtonMenus()
        subscribeToSelectedTabViewModel()

#if !FEEDBACK

        removeFeedback()

#endif

    }

    @IBSegueAction func createAddressBarViewController(_ coder: NSCoder) -> AddressBarViewController? {
        guard let addressBarViewController = AddressBarViewController(coder: coder,
                                                                      tabCollectionViewModel: tabCollectionViewModel) else {
            fatalError("NavigationBarViewController: Failed to init AddressBarViewController")
        }

        self.addressBarViewController = addressBarViewController
        return addressBarViewController
    }

    @IBAction func goBackAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.goBack()
    }

    @IBAction func goForwardAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        selectedTabViewModel.tab.goForward()
    }

    @IBAction func refreshAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        Pixel.fire(.refresh(source: .init(sender: sender, default: .button)))
        selectedTabViewModel.tab.reload()
    }

    @IBAction func optionsButtonAction(_ sender: NSButton) {
        if let event = NSApplication.shared.currentEvent {
            let menu = OptionsButtonMenu(tabCollectionViewModel: tabCollectionViewModel)
            NSMenu.popUpContextMenu(menu, with: event, for: sender)

            switch menu.result {
            case .navigateToBookmark:
                Pixel.fire(.moreMenu(result: .bookmark))
            case .emailProtection:
                Pixel.fire(.moreMenu(result: .emailProtection))
            case .feedback:
                Pixel.fire(.moreMenu(result: .feedback))
            case .fireproof:
                Pixel.fire(.moreMenu(result: .fireproof))
            case .moveTabToNewWindow:
                Pixel.fire(.moreMenu(result: .moveTabToNewWindow))
            case .preferences:
                Pixel.fire(.moreMenu(result: .preferences))
            case .none:
                Pixel.fire(.moreMenu(result: .cancelled))

            case .emailProtectionOff,
                 .emailProtectionCreateAddress,
                 .emailProtectionDashboard,
                 .bookmarkThisPage,
                 .favoriteThisPage:
                break
            }
        }
    }

    @IBAction func shareButtonAction(_ sender: NSButton) {
        guard let url = tabCollectionViewModel.selectedTabViewModel?.tab.url else { return }
        let sharing = NSSharingServicePicker(items: [url])
        sharing.delegate = self
        sharing.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }

#if !FEEDBACK

    private func removeFeedback() {
        feedbackButton.removeFromSuperview()
    }

#endif

    private func setupNavigationButtonMenus() {
        let backButtonMenu = NSMenu()
        backButtonMenu.delegate = goBackButtonMenuDelegate
        goBackButton.menu = backButtonMenu
        let forwardButtonMenu = NSMenu()
        forwardButtonMenu.delegate = goForwardButtonMenuDelegate
        goForwardButton.menu = forwardButtonMenu
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToNavigationActionFlags()
        }
    }

    private func subscribeToNavigationActionFlags() {
        navigationButtonsCancellables.forEach { $0.cancel() }
        navigationButtonsCancellables.removeAll()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            goBackButton.isEnabled = false
            goForwardButton.isEnabled = false
            return
        }
        selectedTabViewModel.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)

        selectedTabViewModel.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateNavigationButtons()
        } .store(in: &navigationButtonsCancellables)
    }

    private func updateNavigationButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        goBackButton.isEnabled = selectedTabViewModel.canGoBack
        goForwardButton.isEnabled = selectedTabViewModel.canGoForward
        refreshButton.isEnabled = selectedTabViewModel.canReload
        shareButton.isEnabled = selectedTabViewModel.canReload
        shareButton.isEnabled = selectedTabViewModel.tab.url != nil
    }

}

extension NavigationBarViewController: NSSharingServicePickerDelegate {

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        return self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        if service == nil {
            Pixel.fire(.sharingMenu(result: .cancelled))
        }
    }
}

extension NavigationBarViewController: NSSharingServiceDelegate {

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        Pixel.fire(.sharingMenu(result: .failure))
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Pixel.fire(.sharingMenu(result: .success))
    }

}
