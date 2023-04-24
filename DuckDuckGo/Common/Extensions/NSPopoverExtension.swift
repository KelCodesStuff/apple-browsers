//
//  NSPopoverExtension.swift
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

import AppKit

extension NSPopover {

    /// Shows the popover below the specified button with the popover's pin positioned in the middle of the button, and a specified y-offset for the pin.
    ///
    /// - Parameters:
    ///   - view: The button below which the popover should appear.
    ///   - yOffset: The y-offset for the popover's pin position relative to the bottom of the button. Default is 5.0 points.
    func showBelow(_ view: NSView) {
        // Set the preferred edge to be the bottom edge of the button
        let preferredEdge: NSRectEdge = .maxY

        // Calculate the positioning rect
        let viewFrame = view.bounds
        let pinPositionX = viewFrame.midX
        let positioningRect = NSRect(x: pinPositionX, y: 0, width: 0, height: 0)

        // Show the popover
        self.show(relativeTo: positioningRect, of: view, preferredEdge: preferredEdge)
    }

}
