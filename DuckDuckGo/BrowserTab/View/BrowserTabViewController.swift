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
    var webView: WKWebView?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let historyViewModel: HistoryViewModel
    private var urlCancelable: AnyCancellable?
    private var selectedTabViewModelCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("BrowserTabViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, historyViewModel: HistoryViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyViewModel = historyViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindSelectedTabViewModel()
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.sinkAsync { [weak self] _ in
            self?.changeTab()
        }
    }

    private func changeTab() {

        func displayWebView(of tabViewModel: TabViewModel) {
            let newWebView = tabViewModel.webView
            newWebView.navigationDelegate = self
            newWebView.uiDelegate = self

            view.addAndLayout(newWebView)
            webView = newWebView
        }

        func bindUrl(of tabViewModel: TabViewModel) {
            urlCancelable?.cancel()
            urlCancelable = tabViewModel.tab.$url.sinkAsync { [weak self] _ in self?.reloadWebViewIfNeeded() }
        }

        if let webView = webView, view.subviews.contains(webView) {
            webView.removeFromSuperview()
        }
        webView = nil

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        displayWebView(of: selectedTabViewModel)
        bindUrl(of: selectedTabViewModel)
        selectedTabViewModel.tab.actionDelegate = self
    }

    private func reloadWebViewIfNeeded() {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        if webView.url == selectedTabViewModel.tab.url { return }

        if let url = selectedTabViewModel.tab.url {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            let request = URLRequest(url: URL.emptyPage)
            webView.load(request)
        }
    }

    private func saveWebsiteVisit() {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }
        
        if let url = webView.url {
            historyViewModel.history.saveWebsiteVisit(url: url, title: webView.title, date: NSDate.now as Date)
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
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }
        
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        if shown {
            selectedTabViewModel.tab.url = nil
        }
        errorView.isHidden = !shown
        webView.isHidden = shown
    }

}

extension BrowserTabViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setFirstResponderIfNeeded()
        displayErrorView(false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        saveWebsiteVisit()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        displayErrorView(true)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        displayErrorView(true)
    }

}

extension BrowserTabViewController: WKUIDelegate {

}

extension BrowserTabViewController: TabActionDelegate {

    func tabForwardAction(_ tab: Tab) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }

        webView.goForward()
    }

    func tabBackAction(_ tab: Tab) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }

        webView.goBack()
    }

    func tabReloadAction(_ tab: Tab) {
        guard let webView = webView else {
            os_log("BrowserTabViewController: Web view is nil", log: OSLog.Category.general, type: .error)
            return
        }

        webView.reload()
    }

}
