//
//  NSAlertExtension.swift
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

import Foundation
import Cocoa

extension NSAlert {

    static var cautionImage = NSImage(named: "NSCaution")

    static func javascriptAlert(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.icon = Self.cautionImage
        alert.messageText = message
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func javascriptConfirmation(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.icon = Self.cautionImage
        alert.messageText = message
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func javascriptTextInput(prompt: String, defaultText: String?) -> NSAlert {
        let alert = NSAlert()
        alert.icon = Self.cautionImage
        alert.messageText = prompt
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.cancel)
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = defaultText
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        return alert
    }

    static func fireproofAlert(with domain: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.fireproofConfirmationTitle(domain: domain)
        alert.informativeText = UserText.fireproofConfirmationMessage
        alert.alertStyle = .warning
        alert.icon = NSImage(named: "Fireproof")
        alert.addButton(withTitle: UserText.fireproof)
        alert.addButton(withTitle: UserText.notNow)
        return alert
    }

    static func fireButtonAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.burnAlertMessageText
        alert.informativeText = UserText.burnAlertInformativeText
        alert.alertStyle = .warning
        alert.icon = NSImage(named: "BurnAlert")
        alert.addButton(withTitle: UserText.burn)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func exportLoginsFailed() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.exportLoginsFailedMessage
        alert.informativeText = UserText.exportLoginsFailedInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func exportBookmarksFailed() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.exportBookmarksFailedMessage
        alert.informativeText = UserText.exportBookmarksFailedInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }
    
    static func cookiePopup() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.autoconsentPopupTitle
        alert.informativeText = UserText.autoconsentPopupDescription
        alert.addButton(withTitle: UserText.autoconsentPopupEnableButton)
        alert.addButton(withTitle: UserText.autoconsentPopupLaterButton)
        alert.addButton(withTitle: UserText.autoconsentPopupNeverButton)
        return alert
    }

}
