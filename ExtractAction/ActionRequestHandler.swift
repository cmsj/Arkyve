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
        let returnURL = writtenURLs.sorted(by: { $0.path < $1.path }).first // FIXME: This is a terrible way to get the single top-most item
        NSLog("extract(): Returning written URL: \(returnURL?.absoluteString ?? "nil")")
        return returnURL
    }
}

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        NSLog("beginRequest(): Starting up... (v21)")
        // Get the input item
        guard let inputItem = context.inputItems.first as? NSExtensionItem else {
            preconditionFailure("beginRequest(): Expected an extension item")
        }

        guard let inputAttachments = inputItem.attachments else {
            preconditionFailure("beginRequest(): Expected a valid array of attachments")
        }
        precondition(inputAttachments.isEmpty == false, "beginRequest(): Expected at least one attachment")

        let outputAttachmentsStore: Mutex<[NSItemProvider]> = Mutex([])
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
                outputAttachmentsStore.withLock { outputAttachments in
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

                    outputAttachments.append(itemProvider)
                    NSLog("beginRequest(): Adding provider output, there are now \(outputAttachments.count) providers")
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            NSLog("beginRequest(): DispatchGroup completed")
            let outputItem = NSExtensionItem()

            let result = outputAttachmentsStore.withLock { (outputAttachments: inout sending [NSItemProvider]) -> [NSItemProvider] in

                if inputAttachments.count < outputAttachments.count {
                    NSLog("beginRequest(): Did not find enough output attachments")
                    return []
                }

                // We can't return outputAttachments because it's isolated by the Mutex, but we know no further
                // changes will happen at this point, so we can return an array of copies
                return outputAttachments.compactMap { $0.copy() as? NSItemProvider }
            }

            if result.isEmpty {
                context.cancelRequest(withError: ArkyveError(.extract, msg: "Unable to extract archive"))
                return
            }

            outputItem.attachments = inputAttachments + result

            NSLog("beginRequest(): Returning completion")
            context.completeRequest(returningItems: [outputItem], completionHandler: nil)
        }
    }
}
