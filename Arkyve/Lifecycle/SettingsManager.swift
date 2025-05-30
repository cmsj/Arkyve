//
//  SettingsManager.swift
//  Arkyve
//
//  Created by Chris Jones on 01/07/2024.
//

import Foundation

enum CacheType: String, CaseIterable {
    case read
    case write
    case drop

    var pathComponent: String {
        switch self {
        case .read:  "read-cache"
        case .write: "write-cache"
        case .drop:  "drop-cache"
        }
    }
}

struct CacheManager {
    static let shared = CacheManager()

    var urls: [CacheType: URL] = [:]
//    let readCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("read-cache")
//    let writeCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("write-cache")
//    let dropCacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("drop-cache")

    private init() {
        for cacheType in CacheType.allCases {
            urls[cacheType] = FileManager.default.temporaryDirectory.appendingPathComponent(cacheType.pathComponent)
            AKTrace("Set \(cacheType) URL to \(urls[cacheType]?.absoluteString ?? "UNKNOWN")")
        }
    }

    func removeCacheDirectories() {
        print("Removing cache directories")
        CacheType.allCases.forEach { cacheType in
            if let url = urls[cacheType] {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func createCacheDirectories() {
        print("Creating cache directories")
        do {
            try CacheType.allCases.forEach { cacheType in
                if let url = urls[cacheType] {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                }
            }
        } catch {
            fatalError("Unable to create cache directories: \(error.localizedDescription)")
        }
    }

    func urlForItem(cacheType: CacheType, itemName: String) -> URL {
        precondition(urls[cacheType] != nil, "Cache directory not found for \(cacheType)")
        return urls[cacheType]!.appendingPathComponent(itemName)
    }

    func isInCache(url: URL, _ cacheTypes: [CacheType] = CacheType.allCases) -> Bool {
        var found = false
        urls.forEach { cacheType, cacheURL in
            if cacheTypes.contains(cacheType) && url.path.hasPrefix(cacheURL.path) {
                found = true
            }
        }
        return found
    }

    func isInCache(path: String, _ cacheTypes: [CacheType] = CacheType.allCases) -> Bool {
        let url = URL(fileURLWithPath: path)
        return isInCache(url: url, cacheTypes)
    }

    func isInDropCache(url: URL) -> Bool {
        return isInCache(url: url, [.drop])
    }

    func isInDropCache(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return isInDropCache(url: url)
    }

    func removeCacheItems(cacheType: CacheType, paths: [String]) {
        guard paths.count > 0 else { return }

        // Let's just be extremely safe about what we're willing to delete
        let filteredPaths = paths.filter { isInCache(path: $0, [cacheType]) }

        // We have some old drop cache items to clean up, we'll farm that out to a detached task
        // so we don't block anything. This work is best-effort, we don't need to care if it fails.
        Task.detached {
            filteredPaths.forEach { path in
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }
}

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
}
