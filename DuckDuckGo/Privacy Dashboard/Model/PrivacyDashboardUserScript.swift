//
//  PrivacyDashboardUserScript.swift
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

import WebKit
import os
import BrowserServicesKit
import TrackerRadarKit

protocol PrivacyDashboardUserScriptDelegate: AnyObject {

    func userScript(_ userScript: PrivacyDashboardUserScript, didChangeProtectionStateTo protectionState: Bool)
    func userScript(_ userScript: PrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState)
    func userScript(_ userScript: PrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool)
    func userScript(_ userScript: PrivacyDashboardUserScript, setHeight height: Int)

}

final class PrivacyDashboardUserScript: NSObject, StaticUserScript {

    enum MessageNames: String, CaseIterable {
        case privacyDashboardSetProtection
        case privacyDashboardFirePixel
        case privacyDashboardSetPermission
        case privacyDashboardSetPermissionPaused
        case privacyDashboardSetHeight
    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    static var source: String = ""
    static var script: WKUserScript = PrivacyDashboardUserScript.makeWKUserScript()
    var messageNames: [String] { MessageNames.allCases.map(\.rawValue) }

    weak var delegate: PrivacyDashboardUserScriptDelegate?
    weak var model: FindInPageModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageType = MessageNames(rawValue: message.name) else {
            assertionFailure("PrivacyDashboardUserScript: unexpected message name \(message.name)")
            return
        }

        switch messageType {
        case .privacyDashboardSetProtection:
            handleSetProtection(message: message)

        case .privacyDashboardFirePixel:
            handleFirePixel(message: message)

        case .privacyDashboardSetPermission:
            handleSetPermission(message: message)

        case .privacyDashboardSetPermissionPaused:
            handleSetPermissionPaused(message: message)

        case .privacyDashboardSetHeight:
            handleSetHeight(message: message)
        }
    }

    private func handleSetProtection(message: WKScriptMessage) {
        guard let isProtected = message.body as? Bool else {
            assertionFailure("privacyDashboardSetProtection: expected Bool")
            return
        }

        delegate?.userScript(self, didChangeProtectionStateTo: isProtected)
    }

    private func handleFirePixel(message: WKScriptMessage) {
        guard let pixel = message.body as? String else {
            assertionFailure("privacyDashboardFirePixel: expected Pixel String")
            return
        }

        Pixel.shared?.fire(pixelNamed: pixel)
    }

    private func handleSetPermission(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let permission = (dict["permission"] as? String).flatMap(PermissionType.init(rawValue:)),
              let state = (dict["value"] as? String).flatMap(PermissionAuthorizationState.init(rawValue:))
        else {
            assertionFailure("privacyDashboardSetPermission: expected { permission: PermissionType, value: PermissionAuthorizationState }")
            return
        }

        delegate?.userScript(self, didSetPermission: permission, to: state)
    }

    private func handleSetPermissionPaused(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let permission = (dict["permission"] as? String).flatMap(PermissionType.init(rawValue:)),
              let paused = dict["paused"] as? Bool
        else {
            assertionFailure("handleSetPermissionPaused: expected { permission: PermissionType, paused: Bool }")
            return
        }

        delegate?.userScript(self, setPermission: permission, paused: paused)
    }

    private func handleSetHeight(message: WKScriptMessage) {
        guard let height = message.body as? Int else {
            assertionFailure("privacyDashboardSetHeght: expected height Int")
            return
        }

        delegate?.userScript(self, setHeight: height)
    }

    typealias AuthorizationState = [(permission: PermissionType, state: PermissionAuthorizationState)]
    func setPermissions(_ usedPermissions: Permissions,
                        authorizationState: AuthorizationState,
                        domain: String,
                        in webView: WKWebView) {

        let allowedPermissions = authorizationState.map { item in
            [
                "key": item.permission.rawValue,
                "title": item.permission.localizedDescription,
                "permission": item.state.rawValue,
                "used": usedPermissions[item.permission] != nil,
                "paused": usedPermissions[item.permission] == .paused,
                "options": PermissionAuthorizationState.allCases.compactMap { decision in
                    // don't show Permanently Allow if can't persist Granted Decision
                    return decision != .grant || item.permission.canPersistGrantedDecision ? [
                        "id": decision.rawValue,
                        "title": String(format: decision.localizedFormat(for: item.permission), domain)
                    ] : nil
                }
            ]
        }
        guard let allowedPermissionsJson = (try? JSONSerialization.data(withJSONObject: allowedPermissions,
                                                                        options: []))?.utf8String()
        else {
            assertionFailure("PrivacyDashboardUserScript: could not serialize permissions object")
            return
        }

        evaluate(js: "window.onChangeAllowedPermissions(\(allowedPermissionsJson))", in: webView)
    }

    func setTrackerInfo(_ tabUrl: URL, trackerInfo: TrackerInfo, webView: WKWebView) {
        guard let trackerBlockingDataJson = try? JSONEncoder().encode(trackerInfo).utf8String() else {
            assertionFailure("Can't encode trackerInfoViewModel into JSON")
            return
        }

        guard let safeTabUrl = try? JSONEncoder().encode(tabUrl).utf8String() else {
            assertionFailure("Can't encode tabUrl into JSON")
            return
        }

        evaluate(js: "window.onChangeTrackerBlockingData(\(safeTabUrl), \(trackerBlockingDataJson))", in: webView)
    }

    func setProtectionStatus(_ isProtected: Bool, webView: WKWebView) {
        evaluate(js: "window.onChangeProtectionStatus(\(isProtected))", in: webView)
    }

    func setUpgradedHttps(_ upgradedHttps: Bool, webView: WKWebView) {
        evaluate(js: "window.onChangeUpgradedHttps(\(upgradedHttps))", in: webView)
    }

    func setParentEntity(_ parentEntity: Entity?, webView: WKWebView) {
        if parentEntity == nil { return }

        guard let parentEntityJson = try? JSONEncoder().encode(parentEntity).utf8String() else {
            assertionFailure("Can't encode parentEntity into JSON")
            return
        }

        evaluate(js: "window.onChangeParentEntity(\(parentEntityJson))", in: webView)
    }

    func setServerTrust(_ serverTrustViewModel: ServerTrustViewModel, webView: WKWebView) {
        guard let certificateDataJson = try? JSONEncoder().encode(serverTrustViewModel).utf8String() else {
            assertionFailure("Can't encode serverTrustViewModel into JSON")
            return
        }

        evaluate(js: "window.onChangeCertificateData(\(certificateDataJson))", in: webView)
    }

    func setIsPendingUpdates(_ isPendingUpdates: Bool, webView: WKWebView) {
        evaluate(js: "window.onIsPendingUpdates(\(isPendingUpdates))", in: webView)
    }

    private func evaluate(js: String, in webView: WKWebView) {
        webView.evaluateJavaScript(js)
    }

}

extension PermissionAuthorizationState {
    func localizedFormat(for permission: PermissionType) -> String {
        switch (permission, self) {
        case (.popups, .ask):
            return UserText.privacyDashboardPopupsAlwaysAsk
        case (_, .ask):
            return UserText.privacyDashboardPermissionAsk
        case (_, .grant):
            return UserText.privacyDashboardPermissionAlwaysAllow
        case (_, .deny):
            return UserText.privacyDashboardPermissionAlwaysDeny
        }
    }
}
