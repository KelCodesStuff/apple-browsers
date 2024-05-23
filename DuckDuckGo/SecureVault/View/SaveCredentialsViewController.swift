//
//  SaveCredentialsViewController.swift
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
import Combine
import Common
import PixelKit

protocol SaveCredentialsDelegate: AnyObject {

    /// May not be called on main thread.
    func shouldCloseSaveCredentialsViewController(_: SaveCredentialsViewController)

}

final class SaveCredentialsViewController: NSViewController {

    static func create() -> SaveCredentialsViewController {
        let storyboard = NSStoryboard(name: "PasswordManager", bundle: nil)
        let controller: SaveCredentialsViewController = storyboard.instantiateController(identifier: "SaveCredentials")
        controller.loadView()

        return controller
    }

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var passwordManagerTitle: NSView!
    @IBOutlet var passwordManagerAccountLabel: NSTextField!
    @IBOutlet weak var passwordManagerTitleLabel: NSTextField!
    @IBOutlet var unlockPasswordManagerTitle: NSView!
    @IBOutlet var faviconImage: NSImageView!
    @IBOutlet var domainLabel: NSTextField!
    @IBOutlet var usernameField: NSTextField!
    @IBOutlet var hiddenPasswordField: NSSecureTextField!
    @IBOutlet var visiblePasswordField: NSTextField!
    @IBOutlet weak var unlockPasswordManagerTitleLabel: NSTextField!
    @IBOutlet weak var usernameFieldTitleLabel: NSTextField!
    @IBOutlet weak var passwordFieldTitleLabel: NSTextField!
    @IBOutlet var notNowSegmentedControl: NSSegmentedControl!
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var updateButton: NSButton!
    @IBOutlet var dontUpdateButton: NSButton!
    @IBOutlet var doneButton: NSButton!
    @IBOutlet var editButton: NSButton!
    @IBOutlet var openPasswordManagerButton: NSButton!
    @IBOutlet weak var passwordManagerNotNowButton: NSButton!
    @IBOutlet var fireproofCheck: NSButton!
    @IBOutlet weak var fireproofCheckDescription: NSTextFieldCell!

    private enum Action {
        case displayed
        case confirmed
        case dismissed
    }

    weak var delegate: SaveCredentialsDelegate?

    private var credentials: SecureVaultModels.WebsiteCredentials?

    private var faviconManagement: FaviconManagement = FaviconManager.shared

    private var passwordManagerCoordinator = PasswordManagerCoordinator.shared

    private var passwordManagerStateCancellable: AnyCancellable?

    private var saveButtonAction: (() -> Void)?

    var passwordData: Data {
        let string = hiddenPasswordField.isHidden ? visiblePasswordField.stringValue : hiddenPasswordField.stringValue
        return string.data(using: .utf8)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        visiblePasswordField.isHidden = true
        saveButton.becomeFirstResponder()
        updateSaveSegmentedControl()
        setUpStrings()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePasswordFieldVisibility(visible: false)

        subscribeToPasswordManagerState()
    }

    override func viewWillDisappear() {
        passwordManagerStateCancellable = nil
    }

    private func setUpStrings() {
        passwordManagerTitleLabel.stringValue = UserText.passwordManagementSaveCredentialsPasswordManagerTitle
        unlockPasswordManagerTitleLabel.stringValue = UserText.passwordManagementSaveCredentialsUnlockPasswordManager
        usernameFieldTitleLabel.stringValue = UserText.authAlertUsernamePlaceholder
        passwordFieldTitleLabel.stringValue = UserText.authAlertPasswordPlaceholder
        fireproofCheck.title = UserText.passwordManagementSaveCredentialsFireproofCheckboxTitle
        fireproofCheckDescription.title = UserText.passwordManagementSaveCredentialsFireproofCheckboxDescription
        saveButton.title = UserText.save
        notNowSegmentedControl.setLabel(UserText.dontSave, forSegment: 0)
        let fontAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
          let titleSize = (UserText.dontSave as NSString).size(withAttributes: fontAttributes)
        notNowSegmentedControl.setWidth(titleSize.width + 16, forSegment: 0)
        notNowSegmentedControl.setLabel(UserText.dontSave, forSegment: 0)
        updateButton.title = UserText.update
        openPasswordManagerButton.title = UserText.bitwardenPreferencesOpenBitwarden
        dontUpdateButton.title = UserText.dontUpdate
        doneButton.title = UserText.done
        editButton.title = UserText.edit
        passwordManagerNotNowButton.title = UserText.notNow
    }

    /// Note that if the credentials.account.id is not nil, then we consider this an update rather than a save.
    func update(credentials: SecureVaultModels.WebsiteCredentials, automaticallySaved: Bool) {
        self.credentials = credentials
        self.domainLabel.stringValue = credentials.account.domain ?? ""
        self.usernameField.stringValue = credentials.account.username ?? ""
        self.hiddenPasswordField.stringValue = String(data: credentials.password ?? Data(), encoding: .utf8) ?? ""
        self.visiblePasswordField.stringValue = self.hiddenPasswordField.stringValue
        self.loadFaviconForDomain(credentials.account.domain)

        if let domain = credentials.account.domain, FireproofDomains.shared.isFireproof(fireproofDomain: domain) {
            fireproofCheck.state = .on
        } else {
            fireproofCheck.state = .off
        }

        // Only use the non-editable state if a credential was automatically saved and it didn't already exist.
        let condition = credentials.account.id != nil && !(credentials.account.username?.isEmpty ?? true) && automaticallySaved
        updateViewState(editable: !condition)

        let existingCredentials = getExistingCredentialsFrom(credentials)
        evaluateCredentialsAndFirePixels(for: .displayed, credentials: existingCredentials)
    }

    private func updateViewState(editable: Bool) {
        usernameField.setEditable(editable)
        hiddenPasswordField.setEditable(editable)
        visiblePasswordField.setEditable(editable)

        if editable || passwordManagerCoordinator.isEnabled {
            notNowSegmentedControl.isHidden = passwordManagerCoordinator.isEnabled || credentials?.account.id != nil
            passwordManagerNotNowButton.isHidden = !passwordManagerCoordinator.isEnabled || credentials?.account.id != nil
            saveButton.isHidden = credentials?.account.id != nil || passwordManagerCoordinator.isLocked
            updateButton.isHidden = credentials?.account.id == nil || passwordManagerCoordinator.isLocked
            dontUpdateButton.isHidden = credentials?.account.id == nil
            openPasswordManagerButton.isHidden = !passwordManagerCoordinator.isLocked

            editButton.isHidden = true
            doneButton.isHidden = true

            titleLabel.isHidden = passwordManagerCoordinator.isEnabled
            passwordManagerTitle.isHidden = !passwordManagerCoordinator.isEnabled || passwordManagerCoordinator.isLocked
            passwordManagerAccountLabel.stringValue = UserText.passwordManagementSaveCredentialsAccountLabel(activeVault: passwordManagerCoordinator.activeVaultEmail ?? "")
            unlockPasswordManagerTitle.isHidden = !passwordManagerCoordinator.isEnabled || !passwordManagerCoordinator.isLocked
            titleLabel.stringValue = UserText.pmSaveCredentialsEditableTitle
            usernameField.makeMeFirstResponder()
        } else {
            notNowSegmentedControl.isHidden = true
            saveButton.isHidden = true
            updateButton.isHidden = true
            dontUpdateButton.isHidden = true

            editButton.isHidden = false
            doneButton.isHidden = false

            titleLabel.stringValue = UserText.pmSaveCredentialsNonEditableTitle
            view.window?.makeFirstResponder(nil)
        }
        let notNowTrailingToOpenPasswordConstraint = passwordManagerNotNowButton.trailingAnchor.constraint(equalTo: openPasswordManagerButton.leadingAnchor, constant: -12)
        let notNowTrailingToSaveButtonConstraint = passwordManagerNotNowButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12)
        let dontUpdateRrailingToOpenPasswordConstraint = dontUpdateButton.trailingAnchor.constraint(equalTo: openPasswordManagerButton.leadingAnchor, constant: -12)
        let dontUpdateTrailingToUpdateButtonConstraint = dontUpdateButton.trailingAnchor.constraint(equalTo: updateButton.leadingAnchor, constant: -12)
        if openPasswordManagerButton.isHidden {
            notNowTrailingToOpenPasswordConstraint.isActive = false
            dontUpdateRrailingToOpenPasswordConstraint.isActive = false
            notNowTrailingToSaveButtonConstraint.isActive = true
            dontUpdateTrailingToUpdateButtonConstraint.isActive = true
        } else {
            notNowTrailingToSaveButtonConstraint.isActive = false
            dontUpdateTrailingToUpdateButtonConstraint.isActive = false
            notNowTrailingToOpenPasswordConstraint.isActive = true
            dontUpdateRrailingToOpenPasswordConstraint.isActive = true
        }
    }

    private func updateSaveSegmentedControl() {
        if notNowSegmentedControl.segmentCount > 1 {
            notNowSegmentedControl.setShowsMenuIndicator(true, forSegment: 1)
        }
        notNowSegmentedControl.selectedSegment = -1
    }

    @IBAction func onSaveClicked(sender: Any?) {
        defer {
            self.delegate?.shouldCloseSaveCredentialsViewController(self)
        }

        var account = SecureVaultModels.WebsiteAccount(username: usernameField.stringValue.trimmingWhitespace(),
                                                       domain: domainLabel.stringValue)
        account.id = credentials?.account.id
        let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: passwordData)
        let existingCredentials = getExistingCredentialsFrom(credentials)

        do {
            if passwordManagerCoordinator.isEnabled {
                guard !passwordManagerCoordinator.isLocked else {
                    os_log("Failed to store credentials: Password manager is locked")
                    return
                }

                passwordManagerCoordinator.storeWebsiteCredentials(credentials) { error in
                    if let error = error {
                        os_log("Failed to store credentials: %s", type: .error, error.localizedDescription)
                    }
                }
            } else {
                _ = try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared).storeWebsiteCredentials(credentials)
                NSApp.delegateTyped.syncService?.scheduler.notifyDataChanged()
                os_log(.debug, log: OSLog.sync, "Requesting sync if enabled")
            }
        } catch {
            os_log("%s:%s: failed to store credentials %s", type: .error, className, #function, error.localizedDescription)
            PixelKit.fire(DebugEvent(GeneralPixel.secureVaultError(error: error)))
        }

        evaluateCredentialsAndFirePixels(for: .confirmed, credentials: existingCredentials)

        PixelKit.fire(GeneralPixel.autofillItemSaved(kind: .password))

        if passwordManagerCoordinator.isEnabled {
            passwordManagerCoordinator.reportPasswordSave()
        }

        if let domain = account.domain {
            if self.fireproofCheck.state == .on {
                FireproofDomains.shared.add(domain: domain)
            } else {
                // If the Fireproof checkbox has been unchecked, and the domain is Fireproof, then un-Fireproof it.
                guard FireproofDomains.shared.isFireproof(fireproofDomain: domain) else { return }
                FireproofDomains.shared.remove(domain: domain)
            }
        }
    }

    @IBAction func onDontUpdateClicked(_ sender: Any) {
        delegate?.shouldCloseSaveCredentialsViewController(self)

        let existingCredentials = getExistingCredentialsFrom(credentials)
        evaluateCredentialsAndFirePixels(for: .dismissed, credentials: existingCredentials)
    }

    @IBAction func onNotNowSegmentedControlClicked(_ sender: Any) {
        if notNowSegmentedControl.selectedSegment == 0 {
            onNotNowClicked(sender: sender)
        } else {
            displayMenuForSecondSegment()
        }
    }

    func displayMenuForSecondSegment() {
        let item = NSMenuItem(title: UserText.neverForThisSite, action: #selector(onNeverPromptClicked), target: self, keyEquivalent: "")
        let menu = NSMenu(title: "", items: [item])

        let segmentWidth = notNowSegmentedControl.bounds.width - 64.0
        let segmentFrame = CGRect(x: segmentWidth, y: 0, width: segmentWidth, height: notNowSegmentedControl.bounds.height)

        if let contentView = notNowSegmentedControl.window?.contentView {
            let menuOrigin = notNowSegmentedControl.convert(segmentFrame.origin, to: contentView)
            let finalMenuOrigin = CGPoint(x: menuOrigin.x, y: menuOrigin.y - segmentFrame.height - 5.0)
            menu.popUp(positioning: nil, at: finalMenuOrigin, in: contentView)
        }

    }

    @IBAction func onNotNowClicked(sender: Any?) {
        func notifyDelegate() {
            delegate?.shouldCloseSaveCredentialsViewController(self)
        }

        let existingCredentials = getExistingCredentialsFrom(credentials)
        evaluateCredentialsAndFirePixels(for: .dismissed, credentials: existingCredentials)

        guard DataClearingPreferences.shared.isLoginDetectionEnabled else {
            notifyDelegate()
            return
        }

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            notifyDelegate()
            return
        }

        let host = domainLabel.stringValue
        // Don't ask if already fireproofed.
        guard !FireproofDomains.shared.isFireproof(fireproofDomain: host) else {
            notifyDelegate()
            return
        }

        let alert = NSAlert.fireproofAlert(with: host.droppingWwwPrefix())
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                FireproofDomains.shared.add(domain: host)
            }
            notifyDelegate()
        }

    }

    @objc func onNeverPromptClicked() {
        do {
            _ = try AutofillNeverPromptWebsitesManager.shared.saveNeverPromptWebsite(domainLabel.stringValue)
        } catch {
            os_log("%: failed to save never prompt for website %s", type: .error, #function, error.localizedDescription)
        }
        PixelKit.fire(GeneralPixel.autofillLoginsSaveLoginModalExcludeSiteConfirmed)

        onNotNowClicked(sender: nil)
    }

    @IBAction func onOpenPasswordManagerClicked(sender: Any?) {
        passwordManagerCoordinator.openPasswordManager()
    }

    @IBAction func onEditClicked(sender: Any?) {
        updateViewState(editable: true)
    }

    @IBAction func onDoneClicked(sender: Any?) {
        delegate?.shouldCloseSaveCredentialsViewController(self)
    }

    @IBAction func onTogglePasswordVisibility(sender: Any?) {
        updatePasswordFieldVisibility(visible: !hiddenPasswordField.isHidden)
    }

    func loadFaviconForDomain(_ domain: String?) {
        guard let domain else {
            faviconImage.image = .web
            return
        }
        faviconImage.image = faviconManagement.getCachedFavicon(for: domain, sizeCategory: .small)?.image ?? .web
    }

    private func updatePasswordFieldVisibility(visible: Bool) {
        if visible {
            visiblePasswordField.stringValue = hiddenPasswordField.stringValue
            visiblePasswordField.isHidden = false
            hiddenPasswordField.isHidden = true
        } else {
            hiddenPasswordField.stringValue = visiblePasswordField.stringValue
            hiddenPasswordField.isHidden = false
            visiblePasswordField.isHidden = true
        }
    }

    private func subscribeToPasswordManagerState() {
        passwordManagerStateCancellable = passwordManagerCoordinator.bitwardenManagement.statusPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateViewState(editable: true)
            }
    }

    private func getExistingCredentialsFrom(_ credentials: SecureVaultModels.WebsiteCredentials?) -> SecureVaultModels.WebsiteCredentials? {
        guard let credentials = credentials, let id = credentials.account.id else {
            return nil
        }

        var existingCredentials: SecureVaultModels.WebsiteCredentials?

        if passwordManagerCoordinator.isEnabled {
            guard !passwordManagerCoordinator.isLocked else {
                os_log("Failed to access credentials: Password manager is locked")
                return existingCredentials
            }

            passwordManagerCoordinator.websiteCredentialsFor(accountId: id) { credentials, _ in
                existingCredentials = credentials
            }
        } else {
            if let idInt = Int64(id) {
                existingCredentials = try? AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared).websiteCredentialsFor(accountId: idInt)
            }
        }

        return existingCredentials
    }

    private func isUsernameUpdated(credentials: SecureVaultModels.WebsiteCredentials) -> Bool {
        if credentials.account.username != self.usernameField.stringValue.trimmingWhitespace() {
            return true
        }
        return false
    }

    private func isPasswordUpdated(credentials: SecureVaultModels.WebsiteCredentials) -> Bool {
        if credentials.password != self.passwordData {
            return true
        }
        return false
    }

    private func evaluateCredentialsAndFirePixels(for action: Action, credentials: SecureVaultModels.WebsiteCredentials?) {
        switch action {
        case .displayed:
            if let credentials = credentials {
                if isPasswordUpdated(credentials: credentials) {
                    PixelKit.fire(GeneralPixel.autofillLoginsUpdatePasswordInlineDisplayed)
                } else {
                    PixelKit.fire(GeneralPixel.autofillLoginsUpdateUsernameInlineDisplayed)
                }
            } else {
                if usernameField.stringValue.trimmingWhitespace().isEmpty {
                    PixelKit.fire(GeneralPixel.autofillLoginsSavePasswordInlineDisplayed)
                } else {
                    PixelKit.fire(GeneralPixel.autofillLoginsSaveLoginInlineDisplayed)
                }
            }
        case .confirmed, .dismissed:
            if let credentials = credentials {
                if isUsernameUpdated(credentials: credentials) {
                    firePixel(for: action,
                              confirmedPixel: GeneralPixel.autofillLoginsUpdateUsernameInlineConfirmed,
                              dismissedPixel: GeneralPixel.autofillLoginsUpdateUsernameInlineDismissed)
                }
                if isPasswordUpdated(credentials: credentials) {
                    firePixel(for: action,
                              confirmedPixel: GeneralPixel.autofillLoginsUpdatePasswordInlineConfirmed,
                              dismissedPixel: GeneralPixel.autofillLoginsUpdatePasswordInlineDismissed)
                }
            } else {
                if usernameField.stringValue.trimmingWhitespace().isEmpty {
                    firePixel(for: action,
                              confirmedPixel: GeneralPixel.autofillLoginsSavePasswordInlineConfirmed,
                              dismissedPixel: GeneralPixel.autofillLoginsSavePasswordInlineDismissed)
                } else {
                    firePixel(for: action,
                              confirmedPixel: GeneralPixel.autofillLoginsSaveLoginInlineConfirmed,
                              dismissedPixel: GeneralPixel.autofillLoginsSaveLoginInlineDismissed)
                }
            }
        }
    }

    private func firePixel(for action: Action, confirmedPixel: PixelKitEventV2, dismissedPixel: PixelKitEventV2) {
        let pixel = action == .confirmed ? confirmedPixel : dismissedPixel
        PixelKit.fire(pixel)
    }

}
