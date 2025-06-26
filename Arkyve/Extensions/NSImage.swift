//
//  NSImage.swift
//  Arkyve
//
//  Created by Chris Jones on 26/06/2025.
//

import AppKit
import SwiftUI

extension NSImage {
    func shareSheetPreviewIcon() -> Image {
        let nsImage = NSImage(size: CGSize(width: 128, height: 128), flipped: false) { rect in
            // FIXME: This sucks because the background doesn't take on material properties.
            NSColor.windowBackgroundColor.set()
            NSBezierPath(rect: rect).fill()
            self.draw(in: rect)

            return true
        }
        return Image(nsImage: nsImage)
    }
}
