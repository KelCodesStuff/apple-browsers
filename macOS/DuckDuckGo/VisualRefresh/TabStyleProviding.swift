//
//  TabStyleProviding.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

protocol TabStyleProviding {
    var separatorColor: NSColor { get }
    var separatorHeight: CGFloat { get }

    var tabsScrollViewHeight: CGFloat { get }
    var pinnedTabsContainerViewHeight: CGFloat { get }
    var standardTabHeight: CGFloat { get }
    var pinnedTabHeight: CGFloat { get }
    var pinnedTabWidth: CGFloat { get }

    var shouldShowSShapedTab: Bool { get }
    var selectedTabColor: NSColor { get }
    var isRoundedBackgroundPresentOnHover: Bool { get }
    var tabSpacing: CGFloat { get }
    var applyTabShadow: Bool { get }
    var standardTabCornerRadius: CGFloat { get }
    var tabButtonActionsCornerRadius: CGFloat { get }
}

final class LegacyTabStyleProvider: TabStyleProviding {
    let separatorColor: NSColor = .separator
    let separatorHeight: CGFloat = 20
    let pinnedTabsContainerViewHeight: CGFloat = 32
    let tabsScrollViewHeight: CGFloat = 36
    let standardTabHeight: CGFloat = 34
    let pinnedTabWidth: CGFloat = 34
    let pinnedTabHeight: CGFloat = 34
    let shouldShowSShapedTab = false
    let selectedTabColor: NSColor = .navigationBarBackground
    let isRoundedBackgroundPresentOnHover = false
    let tabSpacing: CGFloat = 0
    let applyTabShadow: Bool = false
    let standardTabCornerRadius: CGFloat = 8
    let tabButtonActionsCornerRadius: CGFloat = 2
}

final class NewlineTabStyleProvider: TabStyleProviding {
    private let palette: ColorPalette

    var separatorColor: NSColor { palette.decorationTertiary }
    var selectedTabColor: NSColor { palette.surfacePrimary }

    let separatorHeight: CGFloat = 16
    let tabsScrollViewHeight: CGFloat = 38
    let pinnedTabsContainerViewHeight: CGFloat = 38
    let standardTabHeight: CGFloat = 38
    let pinnedTabWidth: CGFloat = 34
    let pinnedTabHeight: CGFloat = 38
    let shouldShowSShapedTab = true
    let isRoundedBackgroundPresentOnHover = true
    let tabSpacing: CGFloat = 1
    let applyTabShadow: Bool = true
    let standardTabCornerRadius: CGFloat = 10.0
    let tabButtonActionsCornerRadius: CGFloat = 5

    init(palette: any ColorPalette) {
        self.palette = palette
    }
}
