//
//  IntentCreate.swift
//  Arkyve
//
//  Created by Chris Jones on 13/06/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers

enum IntentArchiveFormat: String, Codable, Sendable, AppEnum {
    case tar
    case targz
    case tarbz2
    case tarxz
    case zip
    case _7z
    case iso
    case cpio
    case xar

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Archive Format", table: "AppIntents"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) archive formats", table: "AppIntents")
        )
    }

    static let caseDisplayRepresentations: [IntentArchiveFormat: DisplayRepresentation] = [
        .tar: DisplayRepresentation(title: "Tar archive", subtitle: "A tar archive in the PAX Restricted format"),
        .targz: DisplayRepresentation(title: "Tar archive (gzip)", subtitle: "A tar archive in the PAX Restricted format, compressed with gzip"),
        .tarbz2: DisplayRepresentation(title: "Tar archive (bzip2)", subtitle: "A tar archive in the PAX Restricted format, compressed with bzip2"),
        .tarxz: DisplayRepresentation(title: "Tar archive (xz)", subtitle: "A tar archive in the PAX Restricted format, compressed with xz"),
        .zip: DisplayRepresentation(title: "Zip archive", subtitle: "A ZIP archive"),
        ._7z: DisplayRepresentation(title: "7-Zip archive", subtitle: "A 7-Zip archive"),
        .iso: DisplayRepresentation(title: "ISO image", subtitle: "An ISO image file"),
        .cpio: DisplayRepresentation(title: "CPIO archive", subtitle: "A CPIO archive"),
        .xar: DisplayRepresentation(title: "Xar archive", subtitle: "A Xar archive"),
    ]

    var arkyveFormat: ArkyveFormats {
        switch self {
        case .tar: return .tar
        case .targz: return .targz
        case .tarbz2: return .tarbz2
        case .tarxz: return .tarxz
        case .zip: return .zip
        case ._7z: return ._7z
        case .iso: return .iso
        case .cpio: return .cpio
        case .xar: return .xar
        }
    }
}


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
        await vm.saveArchive(to: outputURL, overrideFormat: format.arkyveFormat.libarchiveFormat, overrideFilters: format.arkyveFormat.libarchiveFilters)
        try await vm.waitForArchiveProgressTask()

        return .result(value: IntentFile(fileURL: outputURL))
    }
}
