//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import ZZLog

@Observable
class MainWindowViewModel {
    private(set) var archive: Archive? = nil
    var selectedEntries = Set<ArchiveEntry.ID>()

    var newFolderURL: URL {
        get {
            UserDefaults.standard.url(forKey: "newFolderURL") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        set(url) { UserDefaults.standard.setValue(url, forKey: "newFolderURL") }
    }

    func openArchive(url: URL) {
        let name = url.lastPathComponent
        archive = Archive(name: name, URL: url)
        archive?.open()
    }

    @MainActor func openButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                openArchive(url: url)
            }
        }
    }

    @MainActor func extractButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                Task {
                    archive?.extractEntries(selectedEntries, toFolder: url)
                }
            }
        }
    }

    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        self.archive?.sort(using: using)
    }
}
