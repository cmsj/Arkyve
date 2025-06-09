//
//  IntentList.swift
//  Arkyve
//
//  Created by Chris Jones on 29/05/2025.
//

import Foundation
import AppIntents
import UniformTypeIdentifiers

struct IntentList: AppIntent {

    static let title: LocalizedStringResource = "List archive contents"
    static let description = IntentDescription("Lists the contents of an archive. Supports .zip, .7z, .rar, .iso, .cpio, .tar.gz, .tar.bz, .tar.xz, .lha, .lzh, .cab, .a, .xip, .xar, .pkg.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Archive File",
               description: "An archive file to list",
               supportedContentTypes: [.archive],
               inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var inputFile: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("List the contents of \(\.$inputFile)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        // Check that the incoming file is a format we can handle, by intersecting it with our supported UTTypes
        let inputFileContentTypes = Set(inputFile.availableContentTypes)
        let supportedArchiveTypes = Set(ArkyveFormats.utTypes)
        if inputFileContentTypes.intersection(supportedArchiveTypes).count == 0 {
            NSLog("perform(): Unable to find suitable content type in: \(inputFile.availableContentTypes)")
            throw ArkyveError(.openArchive, msg: "Input file is not a supported archive type: \(inputFile.availableContentTypes)")
        }

        let resultStrings: [String] = try await inputFile.withFile(contentType: .data, allowOpenInPlace: true) { inputURL, _  in
            _ = inputURL.startAccessingSecurityScopedResource()
            defer { inputURL.stopAccessingSecurityScopedResource() }

            NSLog("extract(): Reading source archive: \(inputURL)")
            let archiveModel = await ManagerManagerBase.shared.createVM(url: inputURL)
            let archiveContents = await archiveModel.pathList()
            await ManagerManagerBase.shared.removeVM(archiveModel)

            return archiveContents
        }
        return .result(value: resultStrings)
    }
}
