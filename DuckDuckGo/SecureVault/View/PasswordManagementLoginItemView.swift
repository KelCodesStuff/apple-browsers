//
//  PasswordManagementLoginItemView.swift
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

import Foundation

import SwiftUI
import BrowserServicesKit
import SwiftUIExtensions
import Combine

private let interItemSpacing: CGFloat = 20
private let itemSpacing: CGFloat = 6

struct PasswordManagementLoginItemView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        if model.credentials != nil {

            let editMode = model.isEditing || model.isNew

            ZStack(alignment: .top) {
                Spacer()

                if editMode {

                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(Color(NSColor.editingPanelColor))
                        .shadow(radius: 6)

                }

                VStack(alignment: .leading, spacing: 0) {

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 0) {

                            HeaderView()
                                .padding(.bottom, editMode ? 20 : 30)

                            if model.isEditing || model.isNew {
                                Divider()
                                    .padding(.bottom, 10)
                            }

                            UsernameView()

                            PasswordView()

                            WebsiteView()

                            NotesView()

                            if !model.isEditing && !model.isNew {
                                DatesView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }

                    Spacer(minLength: 0)

                    if model.isEditing {
                        Divider()
                    }

                    Buttons()
                        .padding()

                }
            }
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 10))

        }

    }

}

// MARK: - Generic Views

private struct Buttons: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {
        HStack {

            if model.isEditing && !model.isNew {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())
            }

            Spacer()

            if model.isEditing || model.isNew {
                Button(UserText.pmCancel) {
                    model.cancel()
                }
                .buttonStyle(StandardButtonStyle())
                Button(UserText.pmSave) {
                    model.save()
                }
                .buttonStyle(DefaultActionButtonStyle(enabled: model.isDirty))
                .disabled(!model.isDirty)

            } else {
                Button(UserText.pmDelete) {
                    model.requestDelete()
                }
                .buttonStyle(StandardButtonStyle())

                Button(UserText.pmEdit) {
                    model.edit()
                }
                .buttonStyle(StandardButtonStyle())

            }

        }
    }

}

// MARK: - Login Views

private struct UsernameView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    @State var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmUsername)
                .bold()
                .padding(.bottom, itemSpacing)

            if model.isEditing || model.isNew {

                 TextField("", text: $model.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, interItemSpacing)

            } else {

                HStack(spacing: 6) {
                    Text(model.username)

                    if isHovering {
                        Button {
                            model.copy(model.username)
                        } label: {
                            Image("Copy")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(UserText.copyUsernameTooltip)
                    }

                    Spacer()
                }
                .padding(.bottom, interItemSpacing)
            }

        }
        .onHover {
            isHovering = $0
        }
    }

}

private struct PasswordView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    @State var isHovering = false
    @State var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(UserText.pmPassword)
                .bold()
                .padding(.bottom, itemSpacing)

            if model.isEditing || model.isNew {

                HStack {

                    if isPasswordVisible {

                        TextField("", text: $model.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                    } else {

                        SecureField("", text: $model.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                    }

                    Button {
                        isPasswordVisible = !isPasswordVisible
                    } label: {
                        Image("SecureEyeToggle")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .tooltip(isPasswordVisible ? UserText.hidePasswordTooltip : UserText.showPasswordTooltip)
                    .padding(.trailing, 10)

                }
                .padding(.bottom, interItemSpacing)

            } else {

                HStack(alignment: .center, spacing: 6) {

                    if isPasswordVisible {
                        Text(model.password)
                    } else {
                        Text(model.password.isEmpty ? "" : "••••••••••••")
                    }

                    if isHovering || isPasswordVisible {
                        Button {
                            isPasswordVisible = !isPasswordVisible
                        } label: {
                            Image("SecureEyeToggle")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(isPasswordVisible ? UserText.hidePasswordTooltip : UserText.showPasswordTooltip)
                    }

                    if isHovering {
                        Button {
                            model.copy(model.password)
                        } label: {
                            Image("Copy")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .tooltip(UserText.copyPasswordTooltip)
                    }

                    Spacer()
                }
                .padding(.bottom, interItemSpacing)

            }

        }
        .onHover {
            isHovering = $0
        }
    }

}

private struct WebsiteView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        Text(UserText.pmWebsite)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {

            TextField("", text: $model.domain)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, interItemSpacing)

        } else {
            if let domainURL = model.domain.url {
                TextButton(model.domain) {
                    model.openURL(domainURL)
                }
                .padding(.bottom, interItemSpacing)
            } else {
                Text(model.domain)
                    .padding(.bottom, interItemSpacing)
            }
        }

    }

}

private struct NotesView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel
    let cornerRadius: CGFloat = 8.0
    let borderWidth: CGFloat = 0.4
    let characterLimit: Int = 10000

    var body: some View {

        Text(UserText.pmNotes)
            .bold()
            .padding(.bottom, itemSpacing)

        if model.isEditing || model.isNew {
            if #available(macOS 12, *) {
                FocusableTextEditor()
            } else if #available(macOS 11, *) {
                TextEditor(text: $model.notes)
                    .frame(height: 197.0)
                    .font(.body)
                    .foregroundColor(.primary)
                    .onChange(of: model.notes) {
                        model.notes = String($0.prefix(characterLimit))
                    }
                    .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                                style: .continuous))
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color(NSColor.textEditorBorderColor), lineWidth: borderWidth)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color(NSColor.textEditorBackgroundColor))
                        }
                    )
            } else {
                EditableTextView(text: $model.notes)
                    .frame(height: 197.0)
                    .onReceive(Just(model.notes)) {
                        model.notes = String($0.prefix(characterLimit))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                                style: .continuous))
                    .overlay(
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color(NSColor.textEditorBorderColor), lineWidth: borderWidth)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color(NSColor.textEditorBackgroundColor))
                        }
                        .allowsHitTesting(false)
                    )
            }
        } else {
            Text(model.notes)
                .padding(.bottom, interItemSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu(ContextMenu(menuItems: {
                    Button(UserText.copy, action: {
                        NSPasteboard.general.copy(model.notes)
                    })
                }))
        }

    }

}

@available(macOS 12, *)
struct FocusableTextEditor: View {

    @EnvironmentObject var model: PasswordManagementLoginModel
    @FocusState var isFocused: Bool

    let cornerRadius: CGFloat = 8.0
    let borderWidth: CGFloat = 0.4
    let characterLimit: Int = 10000

    var body: some View {
        TextEditor(text: $model.notes)
            .frame(height: 197.0)
            .font(.body)
            .foregroundColor(.primary)
            .focused($isFocused)
            .padding(EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                        style: .continuous))
            .onChange(of: model.notes) {
                model.notes = String($0.prefix(characterLimit))
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.accentColor.opacity(0.5), lineWidth: 4).opacity(isFocused ? 1 : 0).scaleEffect(isFocused ? 1 : 1.04)
                        .animation(isFocused ? .easeIn(duration: 0.2) : .easeOut(duration: 0.0), value: isFocused)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(NSColor.textEditorBorderColor), lineWidth: borderWidth)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(NSColor.textEditorBackgroundColor))
                }
            )
    }
}

private struct DatesView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()

            HStack {
                Text(UserText.pmLoginAdded)
                    .bold()
                    .opacity(0.6)
                Text(model.createdDate)
                    .opacity(0.6)
            }

            HStack {
                Text(UserText.pmLoginLastUpdated)
                    .bold()
                    .opacity(0.6)
                Text(model.lastUpdatedDate)
                    .opacity(0.6)
            }

            Spacer()
        }
    }

}

private struct HeaderView: View {

    @EnvironmentObject var model: PasswordManagementLoginModel

    var body: some View {

        HStack(alignment: .center, spacing: 0) {

            LoginFaviconView(domain: model.domain)
                .padding(.trailing, 10)

            if model.isNew || model.isEditing {

                TextField(model.domain, text: $model.title)
                    .font(.title)

            } else {

                Text(model.title.isEmpty ? model.domain : model.title)
                    .font(.title)

            }

        }

    }

}

/// Needed to override TextEditor background
extension NSTextView {
  open override var frame: CGRect {
    didSet {
      backgroundColor = .clear
      drawsBackground = true
    }
  }
}
