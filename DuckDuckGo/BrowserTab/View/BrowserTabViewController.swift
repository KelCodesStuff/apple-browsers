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
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.changeWebView()
        }
    }

    private func changeWebView() {

        func displayWebView(of tabViewModel: TabViewModel) {
            let newWebView = tabViewModel.tab.webView
            newWebView.navigationDelegate = self
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
        
        guard let tabViewModel = tabViewModel else {
            os_log("%s: Tab view model is nil", type: .error, className)
            return
        }

        if shown {
            tabViewModel.tab.url = nil
        }
        errorView.isHidden = !shown
        webView.isHidden = shown
    }

    private func openNewTab(with url: URL?) {
        let tab = Tab()
        tab.url = url
        tabCollectionViewModel.append(tab: tab)
    }

}

extension BrowserTabViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        let isCommandPressed = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
        let isLinkActivated = navigationAction.navigationType == .linkActivated
        if isLinkActivated && isCommandPressed {
            decisionHandler(.cancel)
            openNewTab(with: navigationAction.request.url)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setFirstResponderIfNeeded()
        displayErrorView(false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        //todo: Did problems when going back
//        displayErrorView(true)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        displayErrorView(true)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        tabCollectionViewModel.appendNewTabAfterSelected()
        guard let selectedViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return nil
        }
        selectedViewModel.tab.webView.load(navigationAction.request)
        return nil
    }

}

extension BrowserTabViewController: WKUIDelegate {

}
