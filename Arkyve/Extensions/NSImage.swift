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
        return Image(nsImage: asSimpleBitmapWithBackground(width: 128, height: 128, background: NSColor.windowBackgroundColor))
    }

    func asSimpleBitmapWithBackground(width: Int, height: Int, background: NSColor) -> NSImage {
        let nsImage = NSImage(size: CGSize(width: 128, height: 128), flipped: false) { rect in
            // FIXME: This sucks because the background doesn't take on material properties. FB18415902
            background.set()
            NSBezierPath(rect: rect).fill()
            self.draw(in: rect)

            return true
        }
        return nsImage
    }

    // NOTE: This is currently unused, but if we do switch SharePreviews over to being just another DataRepresentaiton in
    // ArchiveEntryExtractable then we'll need it.
    func asPNGData() -> Data {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
        return pngData
    }
}
