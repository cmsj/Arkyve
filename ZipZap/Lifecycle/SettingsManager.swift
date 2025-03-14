//
//  SettingsManager.swift
//  ZipZap
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation
import ZZLog

struct SettingsManager {
    static let shared = SettingsManager()
    let readCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("read-cache")
    let writeCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("write-cache")

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

    private init() {
        let msg = "Cache directories: \(readCacheURL) \(writeCacheURL)"
        #ZZTrace(msg)
    }

    func removeCacheDirectories() {
        try? FileManager.default.removeItem(at: SettingsManager.shared.readCacheURL)
        try? FileManager.default.removeItem(at: SettingsManager.shared.writeCacheURL)
    }

    func createCacheDirectories() {
        do {
            try FileManager.default.createDirectory(at: SettingsManager.shared.readCacheURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: SettingsManager.shared.writeCacheURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Unable to create cache directories: \(error.localizedDescription)")
        }
    }
}
