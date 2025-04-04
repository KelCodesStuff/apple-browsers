//
//  AutoClearTests.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import XCTest
@testable import DuckDuckGo
@testable import Core

class AutoClearTests: XCTestCase {
    
    class MockWorker: AutoClearWorker {

        var clearNavigationStackInvocationCount = 0
        var forgetDataInvocationCount = 0
        var forgetTabsInvocationCount = 0
        var clearDataFinishedInvocationCount = 0

        func clearNavigationStack() {
            clearNavigationStackInvocationCount += 1
        }
        
        func forgetData() {
            forgetDataInvocationCount += 1
        }

        func forgetData(applicationState: Core.DataStoreWarmup.ApplicationState) {
            forgetDataInvocationCount += 1
        }


        func forgetTabs() {
            forgetTabsInvocationCount += 1
        }

        func willStartClearing(_: DuckDuckGo.AutoClear) {

        }

        func autoClearDidFinishClearing(_: DuckDuckGo.AutoClear, isLaunching: Bool) {
            clearDataFinishedInvocationCount += 1
        }
    }
    
    private var worker = MockWorker()
    private var appSettings = AppSettingsMock()

    // Note: applicationDidLaunch based clearing has moved to "configureTabManager" function of
    //  MainViewController to ensure that tabs are removed before the data is cleared.

    func testWhenTimingIsSetToTerminationThenOnlyRestartClearsData() async {
        let logic = AutoClear(worker: worker, appSettings: appSettings)

        appSettings.autoClearAction = .clearData
        appSettings.autoClearTiming = .termination
        
        await logic.clearDataDueToTimeExpired(applicationState: .unknown)
        logic.startClearingTimer()

        XCTAssertFalse(logic.isClearingDue)
    }
    
    func testWhenDesiredTimingIsSetThenDataIsClearedOnceTimeHasElapsed() async {
        let logic = AutoClear(worker: worker, appSettings: appSettings)

        appSettings.autoClearAction = .clearData
        
        let cases: [AutoClearSettingsModel.Timing: TimeInterval] = [.delay5min: 5 * 60,
                                                                    .delay15min: 15 * 60,
                                                                    .delay30min: 30 * 60,
                                                                    .delay60min: 60 * 60]
        
        for (timing, delay) in cases {
            appSettings.autoClearTiming = timing
            
            logic.startClearingTimer(Date().timeIntervalSince1970 - delay + 1)
            XCTAssertFalse(logic.isClearingDue)
            logic.startClearingTimer(Date().timeIntervalSince1970 - delay - 1)
            XCTAssertTrue(logic.isClearingDue)
        }
    }

    func testClearDataClearsNavigationStackAndForgetsData() async {
        let logic = AutoClear(worker: worker, appSettings: appSettings)
        appSettings.autoClearAction = .clearData
        appSettings.autoClearTiming = .delay15min
        await logic.clearDataDueToTimeExpired(applicationState: .active)

        XCTAssertEqual(worker.clearNavigationStackInvocationCount, 1)
        XCTAssertEqual(worker.forgetDataInvocationCount, 1)
    }

}
