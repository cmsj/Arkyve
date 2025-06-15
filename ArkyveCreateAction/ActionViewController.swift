//
//  ActionViewController.swift
//  ArkyveCreateAction
//
//  Created by Chris Jones on 15/06/2025.
//

import Cocoa
import SwiftUI

struct CreateActionView: View {
    var extensionContext: NSExtensionContext?

    var body: some View {
        Text("Hello, World!")
        Button("Click Me") {
            extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
    }
}

class ActionViewController: NSViewController {
    override func loadView() {
        NSLog("ArkyveCreateAction starting up (loadView)")
//        super.loadView()

        view = NSView()

        let swifUIView = CreateActionView(extensionContext: self.extensionContext)
            .frame(minWidth: 400)
            .frame(minHeight: 300)
            .background(Color(NSColor.windowBackgroundColor))

        let hostingView = NSHostingView(rootView: swifUIView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 400, height: 300)

        view.wantsLayer = false
        view.addSubview(hostingView, positioned: .above, relativeTo: nil)
        view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)

//        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame.origin = CGPoint(x: 0, y: 0)

        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        hostingView.setAccessibilityRole(.group)

//        self.view = hostingView
        // Insert code here to customize the view
        NSLog("Input Items = %@", self.extensionContext!.inputItems as NSArray)
    
//        let sharedItem = self.extensionContext!.inputItems[0] as! NSExtensionItem
//        let text = sharedItem.attributedContentText?.string

    }

//    @IBAction func send(_ sender: AnyObject?) {
//        // Note: The extension information in the Info.plist is set to accept any type of content, but this example code only handles text. You should declare the specific types to be supported by your extension in the extension's Info.plist and then make sure to handle all your supported types.
//        let outputItem = NSExtensionItem()
//        outputItem.attributedContentText = self.myTextView.attributedString()
//    
//        let outputItems = [outputItem]
//        self.extensionContext!.completeRequest(returningItems: outputItems, completionHandler: nil)
//    }
//
//    @IBAction func cancel(_ sender: AnyObject?) {
//        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
//        self.extensionContext!.cancelRequest(withError: cancelError)
//    }

}
