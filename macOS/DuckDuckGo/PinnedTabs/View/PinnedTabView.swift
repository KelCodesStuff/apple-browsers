//
//  PinnedTabView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import MaliciousSiteProtection
import SwiftUI
import SwiftUIExtensions

struct PinnedTabView: View, DropDelegate {
    enum Const {
        static let cornerRadius: CGFloat = 10
    }

    let tabStyleProvider: TabStyleProviding

    @ObservedObject var model: Tab
    @EnvironmentObject var collectionModel: PinnedTabsViewModel

    @Environment(\.controlActiveState) private var controlActiveState

    // Hover highlight is disabled while another tab is dragged
    var showsHover: Bool

    var body: some View {
        let stack = ZStack {
            Button { [weak collectionModel, weak model] in
                if !isSelected {
                    collectionModel?.selectedItem = model
                }
            } label: {
                PinnedTabInnerView(
                    width: tabStyleProvider.pinnedTabWidth,
                    height: tabStyleProvider.pinnedTabHeight,
                    isSelected: isSelected,
                    isHovered: collectionModel.hoveredItem == model,
                    foregroundColor: foregroundColor,
                    separatorColor: Color(tabStyleProvider.separatorColor),
                    separatorHeight: tabStyleProvider.separatorHeight,
                    drawSeparator: !collectionModel.itemsWithoutSeparator.contains(model),
                    showSShaped: tabStyleProvider.shouldShowSShapedTab,
                    applyTabShadow: tabStyleProvider.applyTabShadow,
                    roundedHover: tabStyleProvider.isRoundedBackgroundPresentOnHover
                )
                .environmentObject(model)
                .environmentObject(model.crashIndicatorModel)
            }
            .buttonStyle(TouchDownButtonStyle())
            .contextMenu { contextMenu }
            .onDrop(of: [
                NSPasteboard.PasteboardType.URL.rawValue,
                NSPasteboard.PasteboardType.string.rawValue,
            ], delegate: self)

            if !tabStyleProvider.shouldShowSShapedTab {
                BorderView(isSelected: isSelected,
                           cornerRadius: Const.cornerRadius,
                           size: TabShadowConfig.dividerSize)
            }
        }
            .shadow(color: isSelected && tabStyleProvider.applyTabShadow ? Color(.shadowPrimary) : .clear, radius: 6, x: 0, y: -2)

        if controlActiveState == .key {
            stack.onHover { [weak collectionModel, weak model] isHovered in
                collectionModel?.hoveredItem = isHovered ? model : nil
            }
        } else {
            stack
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.url, .text, .data]).first,
              let typeIdentifier = [
                NSPasteboard.PasteboardType.URL.rawValue,
                NSPasteboard.PasteboardType.string.rawValue
              ].first(where: { item.registeredTypeIdentifiers.contains($0) }) else { return false }

        item.loadItem(forTypeIdentifier: typeIdentifier) { (result, _) in
            guard let url = result as? URL ?? ((result as? Data)?.utf8String() ?? result as? String).flatMap(URL.makeURL(from:)) else { return }
            DispatchQueue.main.async {
                model.setUrl(url, source: .userEntered(url.absoluteString, downloadRequested: false))
            }
        }
        return true
    }

    private var isSelected: Bool {
        collectionModel.selectedItem == model
    }

    private var foregroundColor: Color {
        if isSelected {
            return Color(tabStyleProvider.selectedTabColor)
        }
        let isHovered = collectionModel.hoveredItem == model
        return showsHover && isHovered ? Color(tabStyleProvider.selectedTabColor) : Color.clear
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(UserText.duplicateTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.duplicate(model)
        }

        Button(UserText.unpinTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.unpin(model)
        }
        Divider()
        bookmarkAction
        fireproofAction
        Divider()
        switch collectionModel.audioStateView {
        case .muted, .unmuted:
            let audioStateText = collectionModel.audioStateView == .muted ? UserText.unmuteTab : UserText.muteTab
            Button(audioStateText) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.muteOrUmute(model)
            }
            Divider()
        case .notSupported:
            EmptyView()
        }
        Button(UserText.closeTab) { [weak collectionModel, weak model] in
            guard let model = model else { return }
            collectionModel?.close(model)
        }

        if model.canKillWebContentProcess {
            Divider()
            Button { [weak model] in
                model?.killWebContentProcess()
            } label: {
                Text(verbatim: Tab.crashTabMenuOptionTitle)
            }
        }
    }

    @ViewBuilder
    private var fireproofAction: some View {
        if collectionModel.isFireproof(model) {
            Button(UserText.removeFireproofing) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.removeFireproofing(model)
            }
        } else {
            Button(UserText.fireproofSite) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.fireproof(model)
            }
        }
    }

    @ViewBuilder
    private var bookmarkAction: some View {
        if collectionModel.isPinnedTabBookmarked(model) {
            Button(UserText.deleteBookmark) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.removeBookmark(model)
            }
        } else {
            Button(UserText.bookmarkThisPage) { [weak collectionModel, weak model] in
                guard let model = model else { return }
                collectionModel?.bookmark(model)
            }
        }
    }
}

private struct BorderView: View {
    let isSelected: Bool
    let cornerRadius: CGFloat
    let size: CGFloat

    private var borderColor: Color {
        isSelected ? .tabShadowLine : .clear
    }

    private var bottomLineColor: Color {
        isSelected ? .navigationBarBackground : .tabShadowLine
    }

    private var cornerPixelsColor: Color {
        isSelected ? .clear : bottomLineColor
    }

    var body: some View {
        ZStack {
            CustomRoundedCornersShape(inset: 0, tl: cornerRadius, tr: cornerRadius, bl: 0, br: 0)
                .strokeBorder(borderColor, lineWidth: size)

            VStack {
                Spacer()
                HStack {
                    Spacer().frame(width: 1, height: size, alignment: .leading)
                        .background(cornerPixelsColor)

                    Rectangle()
                        .fill(bottomLineColor)
                        .frame(height: size, alignment: .leading)

                    Spacer().frame(width: 1, height: size, alignment: .trailing)
                        .background(cornerPixelsColor)
                }
            }
        }
    }
}

struct PinnedTabInnerView: View {
    let rampSize: CGFloat = 10.0
    let width: CGFloat
    let height: CGFloat
    var isSelected: Bool
    var isHovered: Bool
    var foregroundColor: Color
    var separatorColor: Color
    var separatorHeight: CGFloat
    var drawSeparator: Bool = true
    var showSShaped: Bool
    var applyTabShadow: Bool
    var roundedHover: Bool

    var shouldApplyNewHoverState: Bool {
        return isHovered && !isSelected && roundedHover
    }

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: Tab
    @EnvironmentObject var tabCrashIndicatorModel: TabCrashIndicatorModel
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(foregroundColor)
                .frame(width: shouldApplyNewHoverState ? width - 8 : width, height: shouldApplyNewHoverState ? height - 8 : height)
                .cornerRadius(shouldApplyNewHoverState ? 6 : PinnedTabView.Const.cornerRadius, corners: shouldApplyNewHoverState ? [.topLeft, .topRight, .bottomLeft, .bottomRight] : [.topLeft, .topRight])

            if drawSeparator {
                GeometryReader { proxy in
                    Rectangle()
                        .foregroundColor(separatorColor)
                        .frame(width: 1, height: separatorHeight)
                        .offset(
                            x: showSShaped ? proxy.size.width - rampSize + 2 : proxy.size.width-1,
                            y: showSShaped ? 10 : 6)
                }
            }
            favicon
                .grayscale(controlActiveState == .key ? 0.0 : 1.0)
                .opacity(controlActiveState == .key ? 1.0 : 0.60)
                .frame(maxWidth: 16, maxHeight: 16)
                .aspectRatio(contentMode: .fit)

            if isSelected && showSShaped {
                PinnedTabRampView(rampWidth: rampSize,
                                  rampHeight: rampSize,
                                  foregroundColor: .surfacePrimary)
                .position(x: 2, y: height - (rampSize / 2))

                PinnedTabRampView(rampWidth: rampSize,
                                  rampHeight: rampSize,
                                  isFlippedHorizontally: true,
                                  foregroundColor: .surfacePrimary)
                .position(x: width + rampSize + 2, y: height - (rampSize / 2))
            }
        }
        .frame(
            width: showSShaped ? width + rampSize + 4 : width,
            height: height
        )
    }

    @ViewBuilder
    var audioStateView: some View {
        switch model.webView.audioState {
        case .muted(let isPlayingAudio):
            if isPlayingAudio {
                audioIndicator(isMuted: true)
            } else {
                EmptyView()
            }
        case .unmuted(let isPlayingAudio):
            if isPlayingAudio {
                audioIndicator(isMuted: false)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    var accessoryButton: some View {
        if tabCrashIndicatorModel.isShowingIndicator {
            crashIndicatorView
        } else {
            audioStateView
        }
    }

    private func audioIndicator(isMuted: Bool) -> some View {
        Button {
            model.muteUnmuteTab()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                    .background(Circle().foregroundColor(.pinnedTabMuteStateCircle))
                    .frame(width: 16, height: 16)

                if isMuted {
                    Image(.audioMute)
                        .resizable()
                        .frame(width: 12, height: 12)
                } else {
                    Image(.audio)
                        .resizable()
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: 8, y: -8)
    }

    @ViewBuilder
    var crashIndicatorView: some View {
        Button {
            tabCrashIndicatorModel.isShowingPopover.toggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                    .background(Circle().foregroundColor(.pinnedTabMuteStateCircle))
                    .frame(width: 16, height: 16)

                Image(.tabCrash)
                    .resizable()
                    .frame(width: 12, height: 12)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $tabCrashIndicatorModel.isShowingPopover, arrowEdge: .bottom) {
            PopoverMessageView(
                viewModel: .init(
                    title: UserText.tabCrashPopoverTitle,
                    message: UserText.tabCrashPopoverMessage,
                    maxWidth: TabCrashIndicatorModel.Const.popoverWidth
                ),
                onClick: {
                    tabCrashIndicatorModel.isShowingPopover = false
                }, onClose: {
                    tabCrashIndicatorModel.isShowingPopover = false
                }
            )
        }
        .offset(x: 8, y: -8)
    }

    private var faviconImage: NSImage? {
        if let error = model.error, (error as NSError as? URLError)?.code == .serverCertificateUntrusted || (error as NSError as? MaliciousSiteError != nil) {
            return .redAlertCircle16
        } else if model.error?.isWebContentProcessTerminated == true {
            return .alertCircleColor16
        } else if let favicon = model.favicon {
            return favicon
        }
        return nil
    }

    @ViewBuilder
    var favicon: some View {
        if let favicon = faviconImage {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: favicon)
                    .resizable()
                accessoryButton
            }
        } else if let domain = model.content.userEditableUrl?.host,
                  let eTLDplus1 = ContentBlocking.shared.tld.eTLDplus1(domain),
                  let firstLetter = eTLDplus1.capitalized.first.flatMap(String.init) {
            ZStack {
                Rectangle()
                    .foregroundColor(.forString(eTLDplus1))
                Text(firstLetter)
                    .font(.caption)
                    .foregroundColor(.white)
                accessoryButton
            }
            .cornerRadius(4.0)
        } else {
            ZStack {
                Image(nsImage: .web)
                    .resizable()
                accessoryButton
            }
        }
    }
}
