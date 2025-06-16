//
//  IntentAddToArchive.swift
//  Arkyve
//
//  Created by Chris Jones on 13/06/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers


struct IntentAddToArchive: AppIntent {
    static let title: LocalizedStringResource = "Add files to an archive"
    static let description = IntentDescription("Add files/folders to an existing archive. Supports archives in these formats: .zip, .7z, .iso, .cpio, .tar, .tar.gz, .tar.bz, .tar.xz, .xar")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive",
               description: "The archive you want to add files to",
               supportedContentTypes: [.archive]
    )
    var inputArchive: IntentFile

    @Parameter(title: "Files to add to the archive",
               description: "Files/Folders you want to add to the new archive",
               supportedContentTypes: [.folder, .directory, .data],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var filesToAdd: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Add files/folders to: \(\.$inputArchive)") {
            \.$filesToAdd
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        NSLog("perform(): Inspecting chosen archive...")
        guard let inputArchiveURL = inputArchive.fileURL else {
            throw ArkyveError(.extract, msg: "Input archive missing")
        }

        // Load the existing archive
        NSLog("perform(): Loading \(inputArchiveURL.path)...")
        let vm = await ManagerManager.shared.createVM(url: inputArchiveURL)
        try await vm.waitForArchiveProgressTask()

        guard let arkyveFormat = await vm.format.asArkyveFormat else {
            throw ArkyveError(.readArchive, msg: "Unable to identify archive format of \(inputArchiveURL.path)")
        }

        if !arkyveFormat.canWrite {
            let formatDescription = await vm.format.description
            throw ArkyveError(.writeArchive, msg: "Writing to \(formatDescription) is not supported")
        }

        // Add files/folders to the archive
        let inputFiles = filesToAdd.compactMap({ $0.fileURL })
        NSLog("perform(): Adding \(inputFiles.count) files...")
        try await vm.addFiles(from: inputFiles)

        // Save the archive. We're overriding the format here to ensure we're saving in a variant we trust
        NSLog("perform(): Saving archive...")
        await vm.saveArchiveWithTask(to: inputArchiveURL,
                             overrideFormat: arkyveFormat.libarchiveFormat,
                             overrideFilters: arkyveFormat.libarchiveFilters,
                             addToRecents: false)
        try await vm.waitForArchiveProgressTask()

        return .result(value: true)
    }
}
