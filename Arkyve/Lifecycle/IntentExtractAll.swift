//
//  IntentExtract.swift
//  Arkyve
//
//  Created by Chris Jones on 28/05/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers

struct IntentExtractAll: AppIntent {

    static let title: LocalizedStringResource = "Extract with Arkyve2"
    static let description = IntentDescription("Extracts an archive to a given destination folder. Supports .zip, .7z, .rar, .iso, .cpio, .tar.gz, .tar.bz, .tar.xz, .lha, .lzh, .cab, .a, .xip, .xar, .pkg.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive File",
               description: "An archive file to extract",
               supportedContentTypes: [.archive],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var inputFile: IntentFile

    @Parameter(title: "Destination Folder",
               description: "The folder to extract the archive into. This should be specified as a path, e.g. /path/to/folder. The folder will be created if it does not already exist."
    )
    var destinationFolder: String

    static var parameterSummary: some ParameterSummary {
        Summary("Extract \(\.$inputFile) to \(\.$destinationFolder)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<URL> {
        // If the archive just has one thing in it, we'll extract as-is, but if it has many things
        // we will create an extra top level directory to put them in, and just return that directory
        var returnExtraTopLevelDirectory: Bool = false

        NSLog("perform(): Inspecting chosen destination folder: \(destinationFolder)")
        var outputFolderURL = URL(fileURLWithPath: destinationFolder)
        let (_, outputFolderIsDirectory) = FileManager.default.fileExistsAndIsDirectory(atPath: outputFolderURL.path)
        if !outputFolderIsDirectory {
            throw ArkyveError(.extract, msg: "Destination must be a folder")
        }

        // Check that the incoming file is a format we can handle, by intersecting it with our supported UTTypes
        let inputFileContentTypes = Set(inputFile.availableContentTypes)
        let supportedArchiveTypes = Set(ArkyveFormats.utTypes)
        if inputFileContentTypes.intersection(supportedArchiveTypes).count == 0 {
            NSLog("perform(): Unable to find suitable content type in: \(inputFile.availableContentTypes)")
            throw ArkyveError(.extract, msg: "Archive file is not a supported archive type: \(inputFile.availableContentTypes)")
        }

        let resultURL: URL = try await inputFile.withFile(contentType: .data, allowOpenInPlace: true) { inputURL, _  in
            _ = inputURL.startAccessingSecurityScopedResource()
            defer { inputURL.stopAccessingSecurityScopedResource() }

            NSLog("extract(): Reading source archive: \(inputURL)")
            let archive = try await libarchiveWrapper.loadArchive(at: inputURL)

            if archive.offerTopDirectory {
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
                    throw ArkyveError(.extract, msg: "Unable to get the name of the root archive entry")
                }
                let expectedRootEntryURL = outputFolderURL.appendingPathComponent(rootEntryName)

                guard let returnURL = writtenURLs.first(where: { $0.path == expectedRootEntryURL.path }) else {
                    NSLog("ERROR: Unable to find a matching written URL for the root archive entry")
                    throw ArkyveError(.extract, msg: "Unable to find a matching written URL for the first archive entry")
                }

                NSLog("extract(): Returning written URL: \(returnURL.absoluteString)")
                return returnURL
            }
        }
        return .result(value: resultURL)
    }
}
