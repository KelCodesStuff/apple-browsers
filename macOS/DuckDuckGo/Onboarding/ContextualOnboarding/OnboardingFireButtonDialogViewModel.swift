//
//  OnboardingFireButtonDialogViewModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Combine

public class OnboardingFireButtonDialogViewModel: ObservableObject {

    private var onDismiss: () -> Void
    private var onGotItPressed: () -> Void
    private var onFireButtonPressed: () -> Void
    private let onboardingPixelReporter: OnboardingDialogsReporting

    init(onboardingPixelReporter: OnboardingDialogsReporting = OnboardingPixelReporter(),
         onDismiss: @escaping () -> Void,
         onGotItPressed: @escaping () -> Void,
         onFireButtonPressed: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onGotItPressed = onGotItPressed
        self.onFireButtonPressed = onFireButtonPressed
        self.onboardingPixelReporter = onboardingPixelReporter
    }

    func highFive() {
        onGotItPressed()
        onDismiss()
    }

    func skip() {
        onGotItPressed()
        onboardingPixelReporter.measureFireButtonSkipped()
        onboardingPixelReporter.measureLastDialogShown()
    }

    @MainActor
    func tryFireButton() {
        onFireButtonPressed()
        onboardingPixelReporter.measureFireButtonTryIt()
        FireCoordinator.fireButtonAction()
    }
}
