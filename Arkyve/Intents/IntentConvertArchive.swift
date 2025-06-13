//
//  IntentConvertArchive.swift
//  Arkyve
//
//  Created by Chris Jones on 13/06/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers


struct IntentConvertArchive: AppIntent {
    static let title: LocalizedStringResource = "Convert an archive to a different format"
    static let description = IntentDescription("Create a new compressed archive with the contents of an existing archive. Supports creating archives in these formats: .zip, .7z, .iso, .cpio, .tar, .tar.gz, .tar.bz, .tar.xz, .xar. Supports existing archives in these formats: .zip, .7z, .rar, .iso, .cpio, .tar.gz, .tar.bz, .tar.xz, .lha, .lzh, .cab, .a, .xip, .xar, .pkg")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive Filename",
               description: "The name of the new archive you want to create (with no file extension).",
    )
    var outputArchiveFilename: String

    @Parameter(title: "Existing archive to convert",
               description: "The archive file you want to convert into a new format",
               supportedContentTypes: [.archive],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var inputArchive: IntentFile

    @Parameter(title: "Archive Format",
               description: "The type of archive you want to create",
               default: IntentArchiveFormat.zip)
    var format: IntentArchiveFormat

    @Parameter(title: "Destination Folder",
               description: "The folder to create the archive in",
               supportedContentTypes: [.folder, .directory]
    )
    var destinationFolder: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$inputArchive) to \(\.$destinationFolder)/\(\.$outputArchiveFilename)\(\.$format)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        NSLog("perform(): Inspecting input archive URL...")
        guard let inputArchiveURL = inputArchive.fileURL else {
            throw ArkyveError(.extract, msg: "Input archive missing")
        }
        NSLog("perform(): Inspecting chosen destination folder: \(destinationFolder)")
        guard let outputFolderURL = destinationFolder.fileURL else {
            throw ArkyveError(.extract, msg: "Destination folder missing")
        }
        let (_, outputFolderIsDirectory) = FileManager.default.fileExistsAndIsDirectory(atPath: outputFolderURL.path)
        if !outputFolderIsDirectory {
            throw ArkyveError(.extract, msg: "Destination must be a folder")
        }

        let ext = format.arkyveFormat.ext
        let fullArchiveFilename = "\(outputArchiveFilename).\(ext)"
        let outputURL = outputFolderURL.appendingPathComponent(fullArchiveFilename)
        NSLog("perform(): Determined full output URL will be: \(outputURL)")

        NSLog("perform(): Loading input archive \(inputArchiveURL)...")
        let vm = await ManagerManager.shared.createVM(url: inputArchiveURL)
        try await vm.waitForArchiveProgressTask()

        NSLog("perform(): Saving to \(outputURL) as \(format.arkyveFormat.description)")
        await vm.saveArchive(to: outputURL,
                             overrideFormat: format.arkyveFormat.libarchiveFormat,
                             overrideFilters: format.arkyveFormat.libarchiveFilters,
                             addToRecents: false)
        try await vm.waitForArchiveProgressTask()

        return .result(value: IntentFile(fileURL: outputURL))
    }
}
