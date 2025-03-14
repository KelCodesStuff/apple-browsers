//
//  Text.swift
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

import SwiftUI
import DesignResourcesKit

public struct Label4Style: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    private let design: Font.Design
    private let foregroundColorLight: Color
    private let foregroundColorDark: Color

    public init(design: Font.Design = .default, foregroundColorLight: Color = Color(baseColor: .gray90), foregroundColorDark: Color = .white) {
        self.design = design
        self.foregroundColorLight = foregroundColorLight
        self.foregroundColorDark = foregroundColorDark
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(.callout, design: design))
            .foregroundColor(colorScheme == .light ? foregroundColorLight : foregroundColorDark)
    }
}

public struct Label4SubtitleStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    private let design: Font.Design

    public init(design: Font.Design = .default) {
        self.design = design
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(.callout, design: design))
            .foregroundColor(colorScheme == .light ? Color(baseColor: .gray50) : Color(baseColor: .gray30))
    }
}

public extension View {

    func label4Style(design: Font.Design = .default, foregroundColorLight: Color = Color(baseColor: .gray90), foregroundColorDark: Color = .white) -> some View {
        modifier(Label4Style(design: design, foregroundColorLight: foregroundColorLight, foregroundColorDark: foregroundColorDark))
    }
}

extension Font {
    init(uiFont: UIFont) {
        self = Font(uiFont as CTFont)
    }
}
