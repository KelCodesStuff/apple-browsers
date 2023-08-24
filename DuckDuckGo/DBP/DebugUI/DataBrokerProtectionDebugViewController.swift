//
//  DataBrokerProtectionDebugViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import DataBrokerProtection
import BrowserServicesKit
import Common

final class DataBrokerProtectionDebugViewController: NSViewController {
    var startSchedulerButton: NSButton!
    var startScanButton: NSButton!
    var fakeBrokerTitle: NSTextField!
    var fakeBrokerSwitch: NSSwitch!

    private let fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase

    private var isSchedulerRunning = false
    private var scheduler: DataBrokerProtectionScheduler?

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(fakeBrokerFlag: fakeBrokerFlag)
    }()
    lazy var userProfileViewController: DataBrokerUserProfileViewController = {
        DataBrokerUserProfileViewController(dataManager: dataManager)
    }()

    lazy var profileQueryViewController: DataBrokerProfileQueryViewController = {
        DataBrokerProfileQueryViewController(dataManager: dataManager)
    }()

    init(redeemUseCase: DataBrokerProtectionRedeemUseCase) {
        self.redeemUseCase = redeemUseCase
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDebugScreen()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutDebugScreen()
    }

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768))
        view.wantsLayer = true
        self.view = view
    }

    private func setupDebugScreen() {
        setupScheduler()

        addChild(userProfileViewController)
        view.addSubview(userProfileViewController.view)

        addChild(profileQueryViewController)
        view.addSubview(profileQueryViewController.view)

        startSchedulerButton = NSButton(title: "Start Scheduler", target: self, action: #selector(schedulerActionToggleButtonPressed))
        startScanButton = NSButton(title: "Start Scan", target: self, action: #selector(startScanButtonPressed))

        fakeBrokerTitle = NSTextField()
        fakeBrokerTitle.stringValue = "Use Fake Brokers?"
        fakeBrokerTitle.alignment = .left
        fakeBrokerTitle.isEditable = false
        fakeBrokerTitle.isSelectable = false
        fakeBrokerTitle.isBezeled = false
        fakeBrokerTitle.drawsBackground = false

        fakeBrokerSwitch = NSSwitch()

        if fakeBrokerFlag.isFakeBrokerFlagOn() {
            fakeBrokerSwitch.state = NSSwitch.StateValue.on
        } else {
            fakeBrokerSwitch.state = NSSwitch.StateValue.off
        }

        fakeBrokerSwitch.action = #selector(useFakeBrokerValueChanged(_:))
        fakeBrokerSwitch.target = self

        view.addSubview(startSchedulerButton)
        view.addSubview(startScanButton)
        view.addSubview(fakeBrokerTitle)
        view.addSubview(fakeBrokerSwitch)
    }

    private func layoutDebugScreen() {
        profileQueryViewController.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width * 0.6, height: view.bounds.height)
        profileQueryViewController.view.autoresizingMask = [.width, .height]

        userProfileViewController.view.frame = CGRect(x: profileQueryViewController.view.frame.width, y: 0, width: view.bounds.width * 0.4, height: view.bounds.height)
        userProfileViewController.view.autoresizingMask = [.width, .height]

        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 30
        let spacing: CGFloat = 10
        let buttonY = view.bounds.height - CGFloat(3) * (buttonHeight + spacing)

        startSchedulerButton.frame = CGRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY, width: buttonWidth, height: buttonHeight)
        startScanButton.frame = CGRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY + buttonHeight + spacing, width: buttonWidth, height: buttonHeight)

        fakeBrokerTitle.frame = NSRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY - (buttonHeight + buttonHeight * 0.3), width: buttonWidth, height: buttonHeight)
        fakeBrokerSwitch.frame = NSRect(x: view.bounds.width - buttonWidth - spacing + 32, y: buttonY - buttonHeight, width: buttonWidth, height: buttonHeight)
    }

    @objc func schedulerActionToggleButtonPressed() {
        if isSchedulerRunning {
            scheduler?.stop()
        } else {
            scheduler?.start()
        }
        isSchedulerRunning.toggle()

        updateSchedulerButton()
    }

    private func updateSchedulerButton() {
        let startSchedulerButtonLabel = isSchedulerRunning ? "Stop Scheduler" : "Start Scheduler"
        startSchedulerButton.title = startSchedulerButtonLabel
    }

    @objc func startScanButtonPressed() {
        scheduler?.scanAllBrokers()
    }

    @objc func useFakeBrokerValueChanged(_ sender: NSSwitch) {
        if sender.state == NSControl.StateValue.on {
            fakeBrokerFlag.setFakeBrokerFlag(true)
        } else {
            fakeBrokerFlag.setFakeBrokerFlag(false)
        }

        // This kicks a reload in the fake database
        _ = dataManager.fetchProfile()
    }

    private func setupScheduler() {
        let privacyConfigurationManager = PrivacyFeatures.contentBlocking.privacyConfigurationManager
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)

        let privacySettings = PrivacySecurityPreferences.shared
        let sessionKey = UUID().uuidString
        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: features)

        scheduler = DataBrokerProtectionScheduler(privacyConfigManager: privacyConfigurationManager,
                                                  contentScopeProperties: prefs,
                                                  dataManager: dataManager,
                                                  notificationCenter: NotificationCenter.default,
                                                  errorHandler: DataBrokerProtectionErrorHandling(),
                                                  redeemUseCase: redeemUseCase
        )
    }
}

public class DataBrokerProtectionErrorHandling: EventMapping<DataBrokerProtectionOperationError> {

    public init() {
        super.init { event, _, _, _ in
            Pixel.fire(.debug(event: .dataBrokerProtectionError, error: event.error), withAdditionalParameters: event.params)
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionOperationError>.Mapping) {
        fatalError("Use init()")
    }
}
