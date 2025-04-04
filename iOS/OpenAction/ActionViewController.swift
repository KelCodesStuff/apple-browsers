//
//  ActionViewController.swift
//  OpenAction
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

import Common
import UIKit
import MobileCoreServices
import Core
import UniformTypeIdentifiers
import os.log

class ActionViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {

                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { text, _ in
                        guard let text = text as? String else { return }
                        guard let url = URL.makeSearchURL(text: text) else {
                            Logger.lifecycle.error("Couldn‘t form URL for query “\(text, privacy: .public)”")
                            return
                        }
                        self.launchBrowser(withUrl: url)
                    }
                    break
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { url, _ in
                        guard let url = url as? URL else { return }
                        self.launchBrowser(withUrl: url)
                    }
                    break
                }

            }
        }
    }

    func launchBrowser(withUrl url: URL) {

        DispatchQueue.main.async {
            let path = AppDeepLinkSchemes.quickLink.appending(url.absoluteString)
            guard let url = URL(string: path) else { return }
            var responder = self as UIResponder?
            let selectorOpenURL = sel_registerName("openURL:")
            while let current = responder {
                if #available(iOS 18.0, *) {
                    if let application = current as? UIApplication {
                        application.open(url, options: [:], completionHandler: nil)
                        break
                    }
                } else {
                    if current.responds(to: selectorOpenURL) {
                        current.perform(selectorOpenURL, with: url, afterDelay: 0)
                        break
                    }
                }
                responder = current.next
            }
            self.done()
        }

    }

    func done() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
}
