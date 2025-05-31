//
//  SettingsManager.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import SwiftUI

final class SettingsManager: ObservableObject {
    enum Keys: String, CaseIterable {
        case newFolderURL
        case newArchiveName
        case newArchiveFormat
        case expandSingleRootFolder
        case expandAllFolders

        var id: String { "\(self)" }

        var defaultValue: Any {
            switch(self) {
            case .newFolderURL:
                return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            case .newArchiveName:
                return "Untitled"
            case .newArchiveFormat:
                return ArkyveFormats.zip
            case .expandSingleRootFolder:
                return true
            case .expandAllFolders:
                return false
            }
        }
    }

    @AppStorage(Keys.newFolderURL.id) var newFolderURL: URL = Keys.newFolderURL.defaultValue as! URL
    @AppStorage(Keys.newArchiveName.id) var newArchiveName: String = Keys.newArchiveName.defaultValue as! String
    @AppStorage(Keys.newArchiveFormat.id) var newArchiveFormat: ArkyveFormats = Keys.newArchiveFormat.defaultValue as! ArkyveFormats
    @AppStorage(Keys.expandSingleRootFolder.id) var expandSingleRootFolder: Bool = Keys.expandSingleRootFolder.defaultValue as! Bool
    @AppStorage(Keys.expandAllFolders.id) var expandAllFolders: Bool = Keys.expandAllFolders.defaultValue as! Bool

    func resetToDefaults() {
        newFolderURL = Keys.newFolderURL.defaultValue as! URL
        newArchiveName = Keys.newArchiveName.defaultValue as! String
        newArchiveFormat = Keys.newArchiveFormat.defaultValue as! ArkyveFormats
        expandSingleRootFolder = Keys.expandSingleRootFolder.defaultValue as! Bool
        expandAllFolders = Keys.expandAllFolders.defaultValue as! Bool
    }

    var newArchiveFilters: [libarchiveFilter] {
        get {
            newArchiveFormat.libarchiveFilters
        }
    }
}
