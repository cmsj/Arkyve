//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import os
import ZZLog

import UniformTypeIdentifiers
struct ArchiveDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.bz2, .gzip, .tarArchive, .zip] // FIXME: This list is nonsense
    var archive: Archive

    init(file: Archive? = nil) {
        self.archive = Archive()
    }

    init(configuration: ReadConfiguration) throws {
        if let filename = configuration.file.filename {
            print("Initialised ArchiveDocument for: \(filename)")
            self.archive = Archive(URL: URL(fileURLWithPath: filename))
        } else {
            print("Initialised empty ArchiveDocument")
            self.archive = Archive()
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper()
    }


}

@main
struct ZipZapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.activeViewModel) var activeViewModel

    var body: some Scene {
        DocumentGroup(newDocument: ArchiveDocument()) { file in
            MainWindowView(document: file.$document, fullURL: file.fileURL)
        }
//        WindowGroup(id: "archive-window") {
//            MainWindowView()
//        }
        .commands {
            MenuCommands()
        }
        .restorationBehavior(.disabled)

        UtilityWindow("Log viewer", id: "log-window") {
            LogWindowView()
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
