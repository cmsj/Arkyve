//
//  ActionViewController.swift
//  ArkyveCreateAction
//
//  Created by Chris Jones on 15/06/2025.
//

import Cocoa
import Synchronization
import SwiftUI
import UniformTypeIdentifiers

@MainActor
func processContext(_ context: NSExtensionContext, archiveName: String, archiveFormat: ArkyveFormats) throws {
    NSLog("processContext(): Starting up...")
    // Get the input item
    guard let inputItem = context.inputItems.first as? NSExtensionItem else {
        preconditionFailure("processContext(): Expected an extension item")
    }

    // Get the "attachments" from the input item. These are NSItemProviders
    guard let inputAttachments = inputItem.attachments else {
        preconditionFailure("processContext(): Expected a valid array of attachments")
    }
    precondition(inputAttachments.isEmpty == false, "processContext(): Expected at least one attachment")

    // This first FileManager call is super weird, but it gives you a private, temporary
    // directory to use to write your output files/folders to.
    let itemReplacementDirectory = try FileManager.default.url(for: .itemReplacementDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
                                                               create: true)
    let archiveFullName = "\(archiveName.deletingPathExtension).\(archiveFormat.ext)"
    let writtenURL = itemReplacementDirectory.appendingPathComponent(archiveFullName)
    NSLog("processContext(): Derived archive name: \(archiveFullName)")
    NSLog("processContext(): Will write to: \(writtenURL)")

    // This is how we will schedule our final work to be done after all of our output attachments
    // have finished doing their callback closures. More on this later.
    let dispatchGroup = DispatchGroup()

    let vm = ManagerManager.shared.findOrCreateVM()

    for attachment in inputAttachments {
        dispatchGroup.enter()

        // We need to operate on mutliple UTTypes, so rather than repeat all this code
        // for ~20 types of archive, just grab the UTType of the incoming NSItemProvider and
        // use that to load the FileRepresentation
        guard let attachmentTypeID = attachment.registeredTypeIdentifiers.first else { continue }
        NSLog("beginRequest(): Discovered source type identifier: \(attachmentTypeID)")

        _ = attachment.loadInPlaceFileRepresentation(forTypeIdentifier: attachmentTypeID, completionHandler: { (url, inPlace, error) in
            guard let url else {
                NSLog("processContext(): Unable to get URL for attachment: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
                return
            }
            NSLog("processContext(): Found URL: \(url)")
            Task { @MainActor in
                try? vm.addFiles(from: [url])
                dispatchGroup.leave()
            }
        })
    }

    let itemProvider = NSItemProvider()
    itemProvider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier,
                                            fileOptions: [.openInPlace],
                                            visibility: .all,
                                            loadHandler: { completionHandler in
        Task.detached {
            NSLog("processContext(): In detached task, saving archive...")
            do {
                await vm.saveArchiveWithTask(to: URLBookmark(url: writtenURL, bookmarkData: Data()), addToRecents: false)
                try await vm.waitForArchiveProgressTask()

                await ManagerManager.shared.removeAllVMs()
                completionHandler(writtenURL, false, nil)
            } catch {
                completionHandler(nil, false, error)
            }
        }
        return nil
    })

    dispatchGroup.notify(queue: DispatchQueue.main) {
        NSLog("processContext(): DispatchGroup completed")
        let outputItem = NSExtensionItem()
        outputItem.attachments = inputAttachments + [itemProvider]
        context.completeRequest(returningItems: [outputItem], completionHandler: nil)
    }
}

struct CreateActionView: View {
    @Environment(\.dismiss) var dismiss
    var extensionContext: NSExtensionContext?
    @State var archiveName: String = ""
    @State var archiveFormat: ArkyveFormats = .zip
    @State var isRunning: Bool = false

    func compress() {
        isRunning = true
        if let extensionContext {
            try? processContext(extensionContext, archiveName: archiveName, archiveFormat: archiveFormat)
        }
    }

    var body: some View {
        VStack {
            Text("Unable to proceed")
                .hide(if: extensionContext != nil)
            TextField("Archive Name:", text: $archiveName)
                .onSubmit {
                    compress()
                }
            Picker("Format:", selection: $archiveFormat) {
                ForEach(ArkyveFormats.writeableCases, id: \.self) { format in
                    Text(format.description)
                        .tag(format.rawValue)
                }
            }
            HStack {
                ProgressView()
                    .controlSize(.small)
                    .hide(if: !isRunning)
                Spacer()
                Button("Cancel") {
                    extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
                }
                Button("Compress") {
                    compress()
                }
                .disabled(extensionContext == nil || isRunning)
            }
        }
        .padding()
    }
}

class ActionViewController: NSViewController {
    override func loadView() {
        NSLog("ArkyveCreateAction starting up (loadView)")

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

        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame.origin = CGPoint(x: 0, y: 0)

        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        hostingView.setAccessibilityRole(.group)

        // Insert code here to customize the view
        NSLog("Input Items = %@", self.extensionContext!.inputItems as NSArray)
    }
}
