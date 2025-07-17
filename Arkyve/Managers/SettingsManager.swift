//
//  SettingsManager.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import SwiftUI

final class SettingsManager: ObservableObject {
    @MainActor static let shared = SettingsManager()

    let maxRecents = 9

    enum Keys: String, CaseIterable {
//        case newFolderURL
        case newArchiveName
        case newArchiveFormat
        case folderExpansion
        case recentsData
        case autoSplashWindow
        case iconSize
        case relativeDates
#if DEBUG
        case showDebugUI
#endif

        var id: String { "\(self)" }

        var defaultValue: Any {
            switch(self) {
//            case .newFolderURL:
//                return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            case .newArchiveName:
                return "Untitled"
            case .newArchiveFormat:
                return ArkyveFormats.zip
            case .folderExpansion:
                return FolderExpansionOptions.oneOnly
            case .recentsData:
                return Data()
            case .autoSplashWindow:
                return true
            case .iconSize:
                return 16
            case .relativeDates:
                return true
#if DEBUG
            case .showDebugUI:
                return true
#endif
            }
        }
    }

//    @AppStorage(Keys.newFolderURL.id)     var newFolderURL: URL               = Keys.newFolderURL.defaultValue as! URL
    @AppStorage(Keys.newArchiveName.id)   var newArchiveName: String          = Keys.newArchiveName.defaultValue as! String
    @AppStorage(Keys.newArchiveFormat.id) var newArchiveFormat: ArkyveFormats = Keys.newArchiveFormat.defaultValue as! ArkyveFormats
    @AppStorage(Keys.folderExpansion.id)  var folderExpansion: FolderExpansionOptions = Keys.folderExpansion.defaultValue as! FolderExpansionOptions
    @AppStorage(Keys.recentsData.id)      var recentsData: Data               = Keys.recentsData.defaultValue as! Data
    @AppStorage(Keys.autoSplashWindow.id) var autoSplashWindow: Bool          = Keys.autoSplashWindow.defaultValue as! Bool
    @AppStorage(Keys.iconSize.id)         var iconSize: Int                   = Keys.iconSize.defaultValue as! Int
    @AppStorage(Keys.relativeDates.id)    var relativeDates: Bool             = Keys.relativeDates.defaultValue as! Bool
#if DEBUG
    @AppStorage(Keys.showDebugUI.id)      var showDebugUI: Bool               = Keys.showDebugUI.defaultValue as! Bool
#endif

    var recents: [URLBookmark] {
        get {
            if let decoded = try? JSONDecoder().decode([URLBookmark].self, from: recentsData) {
//                NSLog("Decoded recents from: \(String(data: recentsData, encoding: .utf8)!)")
                return decoded
            }
            return []
        }
        set {
            recentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
//            NSLog("Encoded recents to: \(String(data: recentsData, encoding: .utf8)!)")
        }
    }

    func resetToDefaults() {
//        newFolderURL     = Keys.newFolderURL.defaultValue as! URL
        newArchiveName   = Keys.newArchiveName.defaultValue as! String
        newArchiveFormat = Keys.newArchiveFormat.defaultValue as! ArkyveFormats
        folderExpansion  = Keys.folderExpansion.defaultValue as! FolderExpansionOptions
        autoSplashWindow = Keys.autoSplashWindow.defaultValue as! Bool
        iconSize         = Keys.iconSize.defaultValue as! Int
        relativeDates    = Keys.relativeDates.defaultValue as! Bool
    }

    var newArchiveFilename: String {
        return "\(newArchiveName).\(newArchiveFormat.ext)"
    }

//    var newArchiveURL: URL {
//        return newFolderURL.appendingPathComponent(newArchiveFilename)
//    }

    func addRecent(_ url: URLBookmark) {
        if let index = recents.firstIndex(where: { $0.url == url.url }) {
            // We're opening something already in recents, bump it to the top
            recents.remove(at: index)
        }

        recents.insert(url, at: 0)
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
    }

    func clearRecents() {
        recents.removeAll()
    }

    func checkRecents() {
        recents.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
    }
}
