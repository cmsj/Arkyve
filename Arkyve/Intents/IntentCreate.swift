//
//  IntentCreate.swift
//  Arkyve
//
//  Created by Chris Jones on 13/06/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers


struct IntentCreate: AppIntent {
    static let title: LocalizedStringResource = "Create an archive from some files"
    static let description = IntentDescription("Create a new compressed archive and add some files to it. Supports .zip, .7z, .iso, .cpio, .tar, .tar.gz, .tar.bz, .tar.xz, .xar")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive Filename",
               description: "The name of the archive you want to create (with no file extension).",
//               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var archiveFilename: String

    @Parameter(title: "Files to add to the archive",
               description: "Files/Folders you want to add to the new archive",
               supportedContentTypes: [.folder, .directory, .data],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var filesToAdd: [IntentFile]

    @Parameter(title: "Archive Format",
               description: "The type of archive you want to create",
               default: IntentArchiveFormat.zip)
    var format: IntentArchiveFormat

    @Parameter(title: "Destination Folder",
               description: "The folder to extract the archive into. This should be specified as a path, e.g. /path/to/folder. The folder will be created if it does not already exist.",
               supportedContentTypes: [.folder, .directory]
    )
    var destinationFolder: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$destinationFolder)/\(\.$archiveFilename)\(\.$format)") {
            \.$filesToAdd
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        NSLog("perform(): Inspecting chosen destination folder: \(destinationFolder)")
        guard let outputFolderURL = destinationFolder.fileURL else {
            throw ArkyveError(.extract, msg: "Destination folder missing")
        }
        let (_, outputFolderIsDirectory) = FileManager.default.fileExistsAndIsDirectory(atPath: outputFolderURL.path)
        if !outputFolderIsDirectory {
            throw ArkyveError(.extract, msg: "Destination must be a folder")
        }

        let ext = format.arkyveFormat.ext
        let fullArchiveFilename = "\(archiveFilename).\(ext)"
        let outputURL = outputFolderURL.appendingPathComponent(fullArchiveFilename)

        let vm = await ManagerManager.shared.findOrCreateVM()
        let inputFiles = filesToAdd.compactMap { $0.fileURL }
        try await vm.addFiles(from: inputFiles)
        await vm.saveArchive(to: outputURL,
                             overrideFormat: format.arkyveFormat.libarchiveFormat,
                             overrideFilters: format.arkyveFormat.libarchiveFilters,
                             addToRecents: false)
        try await vm.waitForArchiveProgressTask()

        return .result(value: IntentFile(fileURL: outputURL))
    }
}
