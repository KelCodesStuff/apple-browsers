//
//  BrowserImportViewController.swift
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

protocol BrowserImportViewControllerDelegate: AnyObject {

    func browserImportViewController(_ viewController: BrowserImportViewController, didChangeSelectedImportOptions options: [DataImport.DataType])

}

final class BrowserImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportViewController"
        static let browserWarningBarHeight: CGFloat = 32.0
    }

    static func create(with browser: DataImport.Source, profileList: DataImport.BrowserProfileList) -> BrowserImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> BrowserImportViewController? in
            return BrowserImportViewController(coder: coder, browser: browser, profileList: profileList)
        }
    }

    @IBOutlet var importOptionsStackView: NSStackView!

    @IBOutlet var profileSelectionLabel: NSTextField!
    @IBOutlet var profileSelectionPopUpButton: NSPopUpButton!

    @IBOutlet var bookmarksCheckbox: NSButton!
    @IBOutlet var passwordsCheckbox: NSButton!

    @IBOutlet var closeBrowserWarningLabel: NSTextField!
    @IBOutlet var closeBrowserWarningViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var closeBrowserWarningView: ColorView! {
        didSet {
            closeBrowserWarningView.backgroundColor = NSColor.black.withAlphaComponent(0.05)
        }
    }

    weak var delegate: BrowserImportViewControllerDelegate?

    var selectedImportOptions: [DataImport.DataType] {
        var options = [DataImport.DataType]()

        if bookmarksCheckbox.state == .on && !bookmarksCheckbox.isHidden {
            options.append(.bookmarks)
        }

        if passwordsCheckbox.state == .on && !passwordsCheckbox.isHidden {
            options.append(.logins)
        }

        return options
    }

    var selectedProfile: DataImport.BrowserProfile? {
        guard let selectedProfile = profileSelectionPopUpButton.selectedItem else {
            // If there is no selected item, there should only be one item in the list.
            return profileList.validImportableProfiles.first
        }

        return profileList.validImportableProfiles.first { $0.profileName == selectedProfile.title }
    }

    let browser: DataImport.Source
    let profileList: DataImport.BrowserProfileList

    init?(coder: NSCoder, browser: DataImport.Source, profileList: DataImport.BrowserProfileList) {
        self.browser = browser
        self.profileList = profileList

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(hideOpenBrowserWarningIfNecessary),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)

        // Update the profile picker:

        importOptionsStackView.setCustomSpacing(18, after: profileSelectionPopUpButton)

        if profileList.showProfilePicker {
            profileSelectionPopUpButton.displayBrowserProfiles(profiles: profileList.validImportableProfiles,
                                                               defaultProfile: profileList.defaultProfile)
        } else {
            profileSelectionLabel.isHidden = true
            profileSelectionPopUpButton.isHidden = true
            profileSelectionPopUpButton.removeAllItems()
        }

        passwordsCheckbox.isHidden = browser ==  .safari

        // Toggle the browser warning bar:
        self.closeBrowserWarningLabel.stringValue = UserText.closeBrowserWarningFor(browser: browser.importSourceName)
        hideOpenBrowserWarningIfNecessary()
        
        switch browser {
        case .safari:
            bookmarksCheckbox.title = UserText.bookmarkImportBookmarksAndFavorites
        default:
            bookmarksCheckbox.title = UserText.bookmarkImportBookmarks
        }
    }

    @IBAction func selectedImportOptionsChanged(_ sender: NSButton) {
        delegate?.browserImportViewController(self, didChangeSelectedImportOptions: selectedImportOptions)
    }

    @objc
    private func hideOpenBrowserWarningIfNecessary() {
        let browserIsRunning = ThirdPartyBrowser.browser(for: browser)?.isRunning ?? false
        if browserIsRunning {
            closeBrowserWarningViewHeightConstraint.constant = Constants.browserWarningBarHeight
        } else {
            closeBrowserWarningViewHeightConstraint.constant = 0
        }
    }

}

extension NSPopUpButton {

    fileprivate func displayBrowserProfiles(profiles: [DataImport.BrowserProfile], defaultProfile: DataImport.BrowserProfile?) {
        removeAllItems()

        let validProfiles = profiles.filter { $0.hasLoginData }

        var selectedSourceIndex: Int?

        for (index, profile) in validProfiles.enumerated() {
            addItem(withTitle: profile.profileName)

            if profile.profileName == defaultProfile?.profileName {
                selectedSourceIndex = index
            }
        }

        selectItem(at: selectedSourceIndex ?? 0)
    }

}
