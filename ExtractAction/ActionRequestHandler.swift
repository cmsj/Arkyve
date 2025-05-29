//
//  ActionRequestHandler.swift
//  ExtractAction
//
//  Created by Chris Jones on 22/05/2025.
//

import Foundation
import UniformTypeIdentifiers
import Synchronization

// This is a function that will instantiate our actor, pass it a URL from
// Finder and return the URL of the directory it created with the extracted files
// in it.
func extract(_ url: URL) async throws -> URL? {
    // This first FileManager call is super weird, but it gives you a private, temporary
    // directory to use to write your output files/folders to.
    let itemReplacementDirectory = try FileManager.default.url(for: .itemReplacementDirectory,
                                                               in: .userDomainMask,
                                                               appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
                                                               create: true)

    // If the archive just has one thing in it, we'll extract as-is, but if it has many things
    // we will create an extra top level directory to put them in, and just return that directory
    var returnExtraTopLevelDirectory: Bool = false

    // Now add the name of the archive (the last path component of `url`) to our temporary
    // directory, and create that directory. This is where we'll tell our actor to extract to
    let outputFolderName = url.deletingPathExtension().lastPathComponent.deletingPathExtension
    var outputFolderURL = itemReplacementDirectory.appendingPathComponent(outputFolderName)
    try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)

    NSLog("extract(): Reading source archive: \(url)")
    let archive = try await libarchiveWrapper.loadArchive(at: url)
    guard let rootEntries = archive.root.children else { throw ArkyveError(.extract, msg: "Unable to find archive contents")}

    if rootEntries.count > 1 {
        // We'll enforce an additional top-level directory since we have multiple root entries
        NSLog("extract(): Adding a top-level directory due to multiple root entries")
        returnExtraTopLevelDirectory = true
        outputFolderURL = outputFolderURL.appending(component: archive.name.deletingPathExtension)
        try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
    }

    NSLog("extract(): Attempting to extract to \(outputFolderURL)")

    let writtenURLs = try await archive.extract(toFolder: outputFolderURL, retainFullPath: true, archiveIsNew: false)

    if returnExtraTopLevelDirectory {
        NSLog("extract(): Returning extra top-level directory: \(outputFolderURL)")
        return outputFolderURL
    } else {
        guard let rootEntryName = archive.root.children?.first?.pathComponents.last else {
            NSLog("ERROR: Unable to get the name of the root archive entry")
            return nil
        }
        let expectedRootEntryURL = outputFolderURL.appendingPathComponent(rootEntryName)

        guard let returnURL = writtenURLs.first(where: { $0.path == expectedRootEntryURL.path }) else {
            NSLog("ERROR: Unable to find a matching written URL for the root archive entry")
            return nil
        }

        NSLog("extract(): Returning written URL: \(returnURL.absoluteString)")
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

        // Get the "attachments" from the input item. These are NSItemProviders
        guard let inputAttachments = inputItem.attachments else {
            preconditionFailure("beginRequest(): Expected a valid array of attachments")
        }
        precondition(inputAttachments.isEmpty == false, "beginRequest(): Expected at least one attachment")

        // Because we have two kinds of callback closures, and they are apparently not all
        // clamped to MainActor, we need to make some thread-safe storage for the NSItemProviders
        // we need to create. Mutex will do the job nicely.
        let outputAttachmentsStore: Mutex<[NSItemProvider]> = Mutex([])

        // This is how we will schedule our final work to be done after all of our output attachments
        // have finished doing their callback closures. More on this later.
        let dispatchGroup = DispatchGroup()

        // Iterate the incoming NSItemProviders
        for attachment in inputAttachments {
            // Tell the dispatch group that we're starting a new piece of work
            // (you can also think of this as increasing a reference counter)
            dispatchGroup.enter()

            // We need to operate on mutliple UTTypes, so rather than repeat all this code
            // for ~20 types of archive, just grab the UTType of the incoming NSItemProvider and
            // use that to load the FileRepresentation
            guard let attachmentTypeID = attachment.registeredTypeIdentifiers.first else { continue }
            NSLog("beginRequest(): Discovered source type identifier: \(attachmentTypeID)")

            // This uses the input NSItemProvider to locate the file it relates to and pass it to our closure.
            // The closure's job is to create an NSItemProvider that can be handed back to Finder, and that provider
            // is responsible for producing our output file.
            _ = attachment.loadInPlaceFileRepresentation(forTypeIdentifier: attachmentTypeID) { (url, inPlace, error) in
                // Once we have finished creating the NSItemProvider, signal to the DispatchGroup
                // that we've finished a piece of work (ie decrement a reference counter)
                defer { dispatchGroup.leave() }

                guard let url = url else {
                    NSLog("beginRequest(): Unable to get URL for attachment: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
                    return
                }
                NSLog("beginRequest(): Found URL: \(url)")

                // Enter a context where we have safe access to the contents of our Mutex
                outputAttachmentsStore.withLock { outputAttachments in
                    let itemProvider = NSItemProvider()

                    // Even though we're passing a URL back to Finder, if we tell it it's a UTType.fileURL
                    // all it will do is write a file with the URL inside it.
                    // So instead we will vend a UTType.data.
                    // The closure for this output NSItemProvider is where we'll call our helper function from
                    // earlier.
                    NSLog("beginRequest(): Registering file representation...")
                    itemProvider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier,
                                                            fileOptions: [.openInPlace],
                                                            visibility: .all,
                                                            loadHandler: { completionHandler in
                        NSLog("beginRequest(): in registerFileRepresentation loadHandler")

                        // I found that using a detached Task was necessary here to avoid blocking the thread
                        // we're currently running on.
                        Task.detached {
                            NSLog("beginRequest(): in Task")
                            do {
                                // Now we're in a Task we have an async context, so we can finally call our
                                // extraction helper function from above
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

        // This is the second piece of the DispatchGroup magic.
        // This schedules a closure to run on the main queue when the DispatchGroup
        // has been drained of tasks (ie the reference counter has reached zero).
        // We can't do something like dispatchGroup.wait() because that would block the queue
        // and prevent the various NSItemProvider callbacks from executing.
        dispatchGroup.notify(queue: DispatchQueue.main) {
            NSLog("beginRequest(): DispatchGroup completed")

            // This is the thing we have to return to Finder, and it will contain attachments for all of the
            // NSItemProviders we want to have exist.
            let outputItem = NSExtensionItem()

            let result = outputAttachmentsStore.withLock { (outputAttachments: inout sending [NSItemProvider]) -> [NSItemProvider] in

                // Action Extensions have an interesting quirk - if you don't return all of the input files
                // Finder will assume you've transformed them and will delete them. We don't want that, so we
                // will check we're not going to miss any.
                if inputAttachments.count < outputAttachments.count {
                    NSLog("beginRequest(): Did not find enough output attachments")
                    return []
                }

                // We can't return outputAttachments because it's isolated by the Mutex, but we know no further
                // changes will happen at this point, and NSItemProvider conforms to NSCopying,
                // so we can return an array of copies
                return outputAttachments.compactMap { $0.copy() as? NSItemProvider }
            }

            if result.isEmpty {
                context.cancelRequest(withError: ArkyveError(.extract, msg: "Unable to extract archive"))
                return
            }

            // As mentioned above, we want to tell Finder to not delete all of the input files
            // So we return those NSItemProviders as well as the ones we created.
            outputItem.attachments = inputAttachments + result

            NSLog("beginRequest(): Returning completion")
            context.completeRequest(returningItems: [outputItem], completionHandler: nil)
        }
    }
}
