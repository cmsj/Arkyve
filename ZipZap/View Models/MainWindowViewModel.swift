//
//  MainWindowViewModel.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

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

    func newButton() {
        archive = Archive(name: "Untitled.zip", URL: newFolderURL.appendingPathComponent("Untitled.zip"))
    }

    func openButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                let name = url.lastPathComponent
                archive = Archive(name: name, URL: url)
                archive?.open()
            }
        }
    }

    func closeButton() {
        archive = nil
    }

    func extractButton() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                _ = archive?.extractEntries(selectedEntries, toFolder: url)
            }
        }
    }
}
