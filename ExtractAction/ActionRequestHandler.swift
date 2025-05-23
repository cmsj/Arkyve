//
//  ActionRequestHandler.swift
//  ExtractAction
//
//  Created by Chris Jones on 22/05/2025.
//

import Foundation
import UniformTypeIdentifiers
import Synchronization

func extract(_ url: URL) async throws -> URL? {
    let itemReplacementDirectory = try FileManager.default.url(for: .itemReplacementDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
                                                               create: true)

    var returnExtraTopLevelDirectory: Bool = false

    let outputFolderName = url.deletingPathExtension().lastPathComponent.deletingPathExtension
    var outputFolderURL = itemReplacementDirectory.appendingPathComponent(outputFolderName)
    try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)

    NSLog("extract(): Reading source archive: \(url)")
    var loader = libarchiveWrapper(url: url)
    let archive = try await loader.loadArchive()
    guard let rootEntries = archive.root.children else { throw ArkyveError(.extract, msg: "Unable to find archive contents")}

    if rootEntries.count > 1 {
        // We'll enforce an additional top-level directory since we have multiple root entries
        NSLog("extract(): Adding a top-level directory due to multiple root entries")
        returnExtraTopLevelDirectory = true
        outputFolderURL = outputFolderURL.appending(component: archive.name.deletingPathExtension)
        try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
    }

    NSLog("extract(): Attempting to extract to \(outputFolderURL)")

    let extractables = rootEntries.map { $0.asExtractable(for: archive) }
    loader = libarchiveWrapper(url: url)
    let writtenURLs = try await loader.extract(extractables, toFolder: outputFolderURL, retainFullPath: true, archiveIsNew: false)

    if returnExtraTopLevelDirectory {
        NSLog("extract(): Returning extra top-level directory: \(outputFolderURL)")
        return outputFolderURL
    } else {
        NSLog("extract(): Returning written URL: \(writtenURLs.first?.absoluteString ?? "nil")")
        return writtenURLs.first
    }
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        NSLog("beginRequest(): Starting up... (v19)")
        // Get the input item
        guard let inputItem = context.inputItems.first as? NSExtensionItem else {
            preconditionFailure("beginRequest(): Expected an extension item")
        }

        guard let inputAttachments = inputItem.attachments else {
            preconditionFailure("beginRequest(): Expected a valid array of attachments")
        }
        precondition(inputAttachments.isEmpty == false, "beginRequest(): Expected at least one attachment")

        let outputAttachments: Mutex<[NSItemProvider]> = Mutex([])
        let dispatchGroup = DispatchGroup()

        for attachment in inputAttachments {
            dispatchGroup.enter()

            guard let attachmentTypeID = attachment.registeredTypeIdentifiers.first else { continue }
            NSLog("beginRequest(): Discovered source type identifier: \(attachmentTypeID)")

            _ = attachment.loadInPlaceFileRepresentation(forTypeIdentifier: attachmentTypeID) { (url, inPlace, error) in
                defer { dispatchGroup.leave() }

                guard let url = url else {
                    NSLog("beginRequest(): Unable to get URL for attachment: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
                    return
                }

                NSLog("beginRequest(): Found URL: \(url)")
                let itemProvider = NSItemProvider()

                NSLog("beginRequest(): Registering file representation...")
                itemProvider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier,
                                                        fileOptions: [.openInPlace],
                                                        visibility: .all,
                                                        loadHandler: { completionHandler in
                    NSLog("beginRequest(): in registerFileRepresentation loadHandler")
                    Task.detached {
                        NSLog("beginRequest(): in Task")
                        do {
                            let writtenURL = try await extract(url)
                            completionHandler(writtenURL, false, nil)
                        } catch {
                            completionHandler(nil, false, error)
                        }
                    }
                    return nil
                })

                outputAttachments.withLock {
                    $0.append(itemProvider)
                    NSLog("beginRequest(): Adding provider output, there are now \($0.count) providers")
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            NSLog("beginRequest(): DispatchGroup completed")
            let outputItem = NSExtensionItem()
            outputAttachments.withLock {
                if inputAttachments.count < $0.count {
                    NSLog("beginRequest(): Did not find enough output attachments")
                    context.cancelRequest(withError: ArkyveError(.extract, msg: "Unable to extract archive"))
                    return
                }
                outputItem.attachments = inputAttachments + $0
            }
            NSLog("beginRequest(): Returning completion")
            context.completeRequest(returningItems: [outputItem], completionHandler: nil)
        }
    }

}
