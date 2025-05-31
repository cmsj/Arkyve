//
//  SettingsManager.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation



struct SettingsManager {
    static let shared = SettingsManager()

    var newFolderURL: URL {
        get {
            UserDefaults.standard.url(forKey: "newFolderURL") ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        set(url) {
            UserDefaults.standard.setValue(url, forKey: "newFolderURL")
        }
    }

    var newArchiveName: String {
        get {
            UserDefaults.standard.string(forKey: "newArchiveName") ?? "Untitled"
        }
        set(name) {
            UserDefaults.standard.setValue(name, forKey:"newArchiveName")
        }
    }

    var newArchiveFormat: libarchiveFormat {
        get {
            let rawValue = Int32(UserDefaults.standard.integer(forKey: "newArchiveFormat"))
            if rawValue == 0 {
                return .ZIP
            }
            return libarchiveFormat(rawValue: rawValue) ?? .ZIP
        }
        set(format) {
            UserDefaults.standard.setValue(Int(format.rawValue), forKey: "newArchiveFormat")
        }
    }

    var newArchiveFilters: [libarchiveFilter] {
        get {
            ArkyveFormats.initFromlibarchiveFormatForSaving(newArchiveFormat).libarchiveFilters
        }
    }

    var dontExpandSingleRootFolder: Bool {
        get {
            UserDefaults.standard.bool(forKey: "dontExpandSingleRootFolder")
        }
        set(expand) {
            UserDefaults.standard.setValue(expand, forKey: "dontExpandSingleRootFolder")
        }
    }
}
