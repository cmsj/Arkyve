//
//  SettingsManager.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation

struct SettingsManager {
    static let shared = SettingsManager()
    let readCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("read-cache")
    let writeCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("write-cache")
    let dropCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("drop-cache")

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

    private init() {
        let msg = "Cache directories: \(readCacheURL) \(writeCacheURL)"
        AKTrace(msg)
    }

    func removeCacheDirectories() {
        print("Removing cache directories")
        try? FileManager.default.removeItem(at: readCacheURL)
        try? FileManager.default.removeItem(at: writeCacheURL)
        try? FileManager.default.removeItem(at: dropCacheURL)
    }

    func createCacheDirectories() {
        print("Creating cache directories")
        do {
            try FileManager.default.createDirectory(at: readCacheURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: writeCacheURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: dropCacheURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Unable to create cache directories: \(error.localizedDescription)")
        }
    }
}
