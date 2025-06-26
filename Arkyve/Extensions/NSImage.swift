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
        var imageRect = CGRect(x: 0, y: 0, width: 128, height: 128)
        guard let imageRef = self.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            NSLog("Unable to fetch CGImage for proposed rect \(imageRect), returning original image")
            return Image(nsImage: self)
        }

        let nsImage = NSImage(size: imageRect.size, flipped: false) { rect in
            NSColor.windowBackgroundColor.set()
            NSBezierPath(rect: rect).fill()
            self.draw(in: rect)

            return true
        }
        return Image(nsImage: nsImage)
    }
}
