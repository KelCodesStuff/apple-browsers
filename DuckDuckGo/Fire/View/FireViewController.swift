//
//  FireViewController.swift
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

import Cocoa
import Lottie
import Combine

final class FireViewController: NSViewController {

    static func fireButtonAction() {
        let response = NSAlert.fireButtonAlert().runModal()
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            DispatchQueue.main.async {
                let timedPixel = TimedPixel(.burn())
                let burningWindow: NSWindow
                let waitForOpening: Bool

                if let lastKeyWindow = WindowControllersManager.shared.lastKeyMainWindowController?.window,
                   lastKeyWindow.isVisible {
                    burningWindow = lastKeyWindow
                    waitForOpening = false
                } else {
                    burningWindow = WindowsManager.openNewWindow()!
                    waitForOpening = true
                }

                WindowsManager.closeWindows(except: burningWindow)

                guard let mainViewController = burningWindow.contentViewController as? MainViewController,
                      let fireViewController = mainViewController.fireViewController else {
                    assertionFailure("No burning window")
                    return
                }

                if waitForOpening {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1/3) {
                        fireViewController.fire { timedPixel.fire() }
                    }
                } else {
                    fireViewController.fire { timedPixel.fire() }
                }
            }
        }
    }

    private var fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel

    @IBOutlet weak var fakeFireButton: NSButton!
    @IBOutlet weak var fireAnimationView: AnimationView!
    @IBOutlet weak var progressIndicatorWrapper: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          fireViewModel: FireViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.fireViewModel = fireViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        subscribeToProgress()
        setupView()
        setupFireAnimation()
    }

    override func viewWillAppear() {
        self.view.superview?.isHidden = true
        subscribeToShouldPreventUserInteraction()
    }

    private var shouldPreventUserInteractioCancellable: AnyCancellable?
    private func subscribeToShouldPreventUserInteraction() {
        shouldPreventUserInteractioCancellable = fireViewModel.shouldPreventUserInteraction
            .sink { [weak self] shouldPreventUserInteraction in
                self?.view.superview?.isHidden = !shouldPreventUserInteraction
            }
    }

    private var progressCancellable: AnyCancellable?
    private func subscribeToProgress() {
        progressCancellable = fireViewModel.fire.$progress
            .weakAssign(to: \.doubleValue, on: progressIndicator)
    }

    private func setupView() {
        fakeFireButton.wantsLayer = true
        fakeFireButton.layer?.backgroundColor = NSColor.buttonMouseDownColor.cgColor
    }

    private func setupFireAnimation() {
        fireAnimationView.contentMode = .scaleToFill
    }

    private func fire(completion: (() -> Void)? = nil) {
        progressIndicatorWrapper.isHidden = true

        fireViewModel.isAnimationPlaying = true
        fireAnimationView.play { [weak self] _ in
            guard let self = self else { return }

            self.fireViewModel.isAnimationPlaying = false
            if self.fireViewModel.fire.isBurning {
                self.progressIndicatorWrapper.isHidden = false
            }
        }

        self.fireViewModel.fire.burnAll(tabCollectionViewModel: self.tabCollectionViewModel, completion: completion)
    }

}
