//
//  BrowserTabViewController.swift
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
import WebKit
import os.log
import Combine

class BrowserTabViewController: NSViewController {

    @IBOutlet weak var errorView: NSView!
    var webView: WebView?
    var tabViewModel: TabViewModel?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var urlCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var isErrorViewVisibleCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        subscribeToSelectedTabViewModel()
        subscribeToIsErrorViewVisible()
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.changeWebView()
            self?.subscribeToIsErrorViewVisible()
        }
    }

    private func changeWebView() {

        func displayWebView(of tabViewModel: TabViewModel) {
            tabViewModel.tab.delegate = self

            let newWebView = tabViewModel.tab.webView
            newWebView.uiDelegate = self

            view.addAndLayout(newWebView)
            webView = newWebView
        }

        func subscribeToUrl(of tabViewModel: TabViewModel) {
            urlCancellable?.cancel()
            urlCancellable = tabViewModel.tab.$url.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.reloadWebViewIfNeeded() }
        }

        if let webView = webView, view.subviews.contains(webView) {
            webView.removeFromSuperview()
        }
        webView = nil
        guard let tabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            self.tabViewModel = nil
            return
        }
        self.tabViewModel = tabViewModel

        displayWebView(of: tabViewModel)
        subscribeToUrl(of: tabViewModel)
    }

    private func subscribeToIsErrorViewVisible() {
        isErrorViewVisibleCancellable = tabViewModel?.$isErrorViewVisible.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.displayErrorView(self?.tabViewModel?.isErrorViewVisible ?? false)
        }
    }

    private func reloadWebViewIfNeeded() {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        guard let tabViewModel = tabViewModel else {
            os_log("%s: Tab view model is nil", type: .error, className)
            return
        }

        if webView.url == tabViewModel.tab.url { return }

        if let url = tabViewModel.tab.url {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            let request = URLRequest(url: URL.emptyPage)
            webView.load(request)
        }
    }

    private func setFirstResponderIfNeeded() {
        guard let url = webView?.url else {
            return
        }

        if !url.isDuckDuckGoSearch {
            view.window?.makeFirstResponder(webView)
        }
    }

    private func displayErrorView(_ shown: Bool) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", type: .error)
            return
        }

        errorView.isHidden = !shown
        webView.isHidden = shown
    }

    private func openNewTab(with url: URL?) {
        let tab = Tab()
        tab.url = url
        tabCollectionViewModel.appendWithoutSelection(tab: tab)
    }

}

extension BrowserTabViewController: TabDelegate {

    func tabDidStartNavigation(_ tab: Tab) {
        setFirstResponderIfNeeded()
    }

    func tab(_ tab: Tab, requestedNewTab url: URL?) {
        openNewTab(with: url)
    }

    func tab(_ tab: Tab, requestedFileDownload download: FileDownload) {
        print(#function, download)
        FileDownloadManager.shared.startDownload(download)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        //  Safari closes new tabs that were opened and then create a download instantly.  Should we do the same?
    }

    func tab(_ tab: Tab, requestedContextMenuAt position: NSPoint, forElements elements: [ContextMenuElement]) {

        print(#function, position, elements)

        var menuItems = [NSMenuItem]()

        if elements.isEmpty {
            menuItems.append(.contextMenuBack)
            menuItems.append(.contextMenuForward)
            menuItems.append(.contextMenuReload)
        } else {

            // images are first in the list, but we want them at the end of the menu
            elements.reversed().forEach {
                if !menuItems.isEmpty {
                    menuItems.append(.separator())
                }

                switch $0 {

                case .link(let url):
                    NSMenuItem.linkContextMenuItems.forEach {
                        ($0 as? URLContextMenuItem)?.url = url
                        menuItems.append($0)
                    }

                case .image(let url):
                    NSMenuItem.imageContextMenuItems.forEach {
                        ($0 as? URLContextMenuItem)?.url = url
                        menuItems.append($0)
                    }

                }
            }
        }

        let menu = NSMenu()
        menu.delegate = self
        menuItems.forEach { menu.addItem($0) }
        view.window?.makeKey()
        view.window?.makeFirstResponder(self) // we want this controller to handle actions first, before the parent controller
        menu.popUp(positioning: nil, at: view.convert(position, from: webView), in: view)

    }

}

extension BrowserTabViewController: NSMenuDelegate {

    func menuWillOpen(_ menu: NSMenu) {
        print(#function)
        NSMenuItem.contextMenuBack.isHidden = !(tabViewModel?.canGoBack ?? false)
        NSMenuItem.contextMenuForward.isHidden = !(tabViewModel?.canGoForward ?? false)
        NSMenuItem.contextMenuReload.isHidden = !(tabViewModel?.canReload ?? false)
    }

}

extension BrowserTabViewController: LinkMenuItemSelectors {

    func openLinkInNewTab(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)
        openNewTab(with: sender.url)
    }

    func openLinkInNewWindow(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)
        WindowsManager.openNewWindow(with: sender.url)
    }

    func downloadLinkedFile(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)

        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = sender.url else { return }

        self.tab(tab, requestedFileDownload: FileDownload(request: URLRequest(url: url), suggestedName: nil))
    }

    func copyLink(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)

        guard let url = sender.url?.absoluteString else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .URL)

    }

}

extension BrowserTabViewController: ImageMenuItemSelectors {

    func openImageInNewTab(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)
        openNewTab(with: sender.url)
    }

    func openImageInNewWindow(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)
        WindowsManager.openNewWindow(with: sender.url)
    }

    func saveImageToDownloads(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)
        
        guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab,
              let url = sender.url else { return }

        self.tab(tab, requestedFileDownload: FileDownload(request: URLRequest(url: url), suggestedName: nil))
    }

    func copyImageAddress(_ sender: URLContextMenuItem) {
        print(#function, sender.url as Any)

        guard let url = sender.url?.absoluteString else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .URL)

    }

}

extension BrowserTabViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        // Returned web view must be created with the specified configuration.
        tabCollectionViewModel.appendNewTabAfterSelected(with: configuration)
        guard let selectedViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return nil
        }
        // WebKit loads the request in the returned web view.
        return selectedViewModel.tab.webView
    }
    
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(nil)
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

        openPanel.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler()
            return
        }

        let alert = NSAlert.javascriptAlert(with: message)
        alert.beginSheetModal(for: window) { _ in
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(false)
            return
        }

        let alert = NSAlert.javascriptConfirmation(with: message)
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        guard let window = view.window else {
            os_log("%s: Window is nil", type: .error, className)
            completionHandler(nil)
            return
        }

        let alert = NSAlert.javascriptTextInput(prompt: prompt, defaultText: defaultText)
        alert.beginSheetModal(for: window) { response in
            guard let textField = alert.accessoryView as? NSTextField else {
                os_log("BrowserTabViewController: Textfield not found in alert", type: .error)
                completionHandler(nil)
                return
            }
            let answer = response == .alertFirstButtonReturn ? textField.stringValue : nil
            completionHandler(answer)
        }
    }

}

fileprivate extension NSAlert {

    static func javascriptAlert(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        return alert
    }

    static func javascriptConfirmation(with message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func javascriptTextInput(prompt: String, defaultText: String?) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = defaultText
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        return alert
    }

}
