//
//  IntentExtractSome.swift
//  Arkyve
//
//  Created by Chris Jones on 29/05/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers

struct IntentExtractSome: AppIntent {

    static let title: LocalizedStringResource = "Extract some files from archive"
    static let description = IntentDescription("Extracts some files from an archive to a given destination folder. Supports .zip, .7z, .rar, .iso, .cpio, .tar.gz, .tar.bz, .tar.xz, .lha, .lzh, .cab, .a, .xip, .xar, .pkg.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive File",
               description: "An archive file to extract",
               supportedContentTypes: [.archive],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var inputFile: IntentFile

    @Parameter(title: "Entry Paths",
               description: "Paths within the archive to extract")
    var entryPaths: [String]

    @Parameter(title: "Retain full path",
               description: "If this is true, extracted entries will be placed in the equivalent folder hierarchy as they were in the archive. If this is false, the chosen entries will be extracted without any additional parent folders",
               default: true)
    var retainFullPath: Bool

    @Parameter(title: "Destination Folder",
               description: "The folder to extract the archive into. This should be specified as a path, e.g. /path/to/folder. The folder will be created if it does not already exist.",
               supportedContentTypes: [.folder, .directory]
    )
    var destinationFolder: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Extract \(\.$entryPaths) from \(\.$inputFile) to \(\.$destinationFolder)") {
            \.$retainFullPath
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[URL]> {
        NSLog("perform(): Inspecting chosen destination folder: \(destinationFolder)")
        guard var outputFolderURL = destinationFolder.fileURL else {
            throw ArkyveError(.extract, msg: "Destination folder missing")
        }
        let (_, outputFolderIsDirectory) = FileManager.default.fileExistsAndIsDirectory(atPath: outputFolderURL.path)
        if !outputFolderIsDirectory {
            throw ArkyveError(.extract, msg: "Destination must be a folder")
        }

        // Check that the incoming file is a format we can handle, by intersecting it with our supported UTTypes
        let inputFileContentTypes = Set(inputFile.availableContentTypes)
        let supportedArchiveTypes = Set(ArkyveFormats.utTypes)
        if inputFileContentTypes.intersection(supportedArchiveTypes).count == 0 {
            NSLog("perform(): Unable to find suitable content type in: \(inputFile.availableContentTypes)")
            throw ArkyveError(.extract, msg: "Input file is not a supported archive type: \(inputFile.availableContentTypes)")
        }

        let resultURL: [URL] = try await inputFile.withFile(contentType: .data, allowOpenInPlace: true) { inputURL, _  in
            _ = inputURL.startAccessingSecurityScopedResource()
            defer { inputURL.stopAccessingSecurityScopedResource() }

            NSLog("extract(): Reading source archive: \(inputURL)")
            let archiveModel = await ManagerManagerBase.shared.createVM(url: inputURL)
            try await archiveModel.waitForArchiveOpen()

            NSLog("extract(): Attempting to extract \(entryPaths.count) entries to \(outputFolderURL)")
            let writtenURLs = try await archiveModel.extract(paths: entryPaths, toFolder: outputFolderURL, retainFullPath: retainFullPath)

            await ManagerManagerBase.shared.removeVM(archiveModel)
            return writtenURLs
        }
        return .result(value: resultURL)
    }
}
