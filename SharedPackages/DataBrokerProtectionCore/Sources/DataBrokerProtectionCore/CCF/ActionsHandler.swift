//
//  ActionsHandler.swift
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

public class ActionsHandler {
    private var lastExecutedActionIndex: Int?

    var captchaTransactionId: CaptchaTransactionId?

    public let step: Step

    public init(step: Step) {
        self.step = step
    }

    public func currentAction() -> Action? {
        guard let lastExecutedActionIndex = self.lastExecutedActionIndex else { return nil }

        if lastExecutedActionIndex < step.actions.count {
            return step.actions[lastExecutedActionIndex]
        } else {
            return nil
        }
    }

    public func nextAction() -> Action? {
        guard let lastExecutedActionIndex = self.lastExecutedActionIndex else {
            // If last executed action index is nil. Means we didn't execute any action, so we return the first action.
            self.lastExecutedActionIndex = 0
            return step.actions.first
        }

        let nextActionIndex = lastExecutedActionIndex + 1

        if nextActionIndex < step.actions.count {
            self.lastExecutedActionIndex = nextActionIndex
            return step.actions[nextActionIndex]
        } else {
            return nil // No more actions to execute
        }
    }
}
