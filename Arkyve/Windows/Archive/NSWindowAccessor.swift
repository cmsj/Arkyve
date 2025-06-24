//
//  NSWindowAccessor.swift
//  Arkyve
//
//  Created by Chris Jones on 08/06/2025.
//

import SwiftUI

struct NSWindowAccessor: NSViewRepresentable {
    @State var viewModel: ArchiveViewModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            print("\(viewModel.id): Attaching NSWindow to viewModel")
            viewModel.window = view.window   // << right after inserted in window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
