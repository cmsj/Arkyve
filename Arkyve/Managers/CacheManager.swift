//
//  CacheManager.swift
//  Arkyve
//
//  Created by Chris Jones on 30/05/2025.
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
    let baseID: UUID
    let baseURL: URL
    var cacheURLs: [CacheType: URL] = [:]

    static let dropCache = CacheManager(for: UUID())

    init(for baseID: UUID) {
        self.baseID = baseID
        self.baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(baseID.uuidString)
        AKTrace("\(baseID): CacheManager init for: \(baseURL.absoluteString)")

        for cacheType in CacheType.allCases {
            cacheURLs[cacheType] = baseURL.appendingPathComponent(cacheType.pathComponent)
        }

        createCacheDirectories()
    }

    func removeCacheDirectories() {
        AKTrace("\(baseID): Removing cache directories")
        CacheType.allCases.forEach { cacheType in
            if let url = cacheURLs[cacheType] {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? FileManager.default.removeItem(at: baseURL)
    }

    func createCacheDirectories() {
        AKTrace("\(baseID): Creating cache directories")
        do {
            try CacheType.allCases.forEach { cacheType in
                if let url = cacheURLs[cacheType] {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                }
            }
        } catch {
            fatalError("\(baseID): Unable to create cache directories: \(error.localizedDescription)")
        }
    }

    func urlForItem(cacheType: CacheType, itemName: String) -> URL {
        precondition(cacheURLs[cacheType] != nil, "Cache directory not found for \(cacheType)")
        return cacheURLs[cacheType]!.appendingPathComponent(itemName)
    }

    func isInCache(url: URL, _ cacheTypes: [CacheType] = CacheType.allCases) -> Bool {
        var found = false
        cacheURLs.forEach { cacheType, cacheURL in
            if cacheTypes.contains(cacheType) && url.path.hasPrefix(cacheURL.path) {
                found = true
            }
        }
        if found == true {
            AKTrace("\(baseID): Found in \(cacheTypes): \(found) for \(url)")
        }
        return found
    }

    func isInDropCache(url: URL) -> Bool {
        return isInCache(url: url, [.drop])
    }

    func removeCacheItems(cacheType: CacheType, urls: [URL]) {
        guard urls.count > 0 else { return }

        // Let's just be extremely safe about what we're willing to delete
        let filteredURLs = urls.filter { isInCache(url: $0, [cacheType]) }

        // We have some old drop cache items to clean up, we'll farm that out to a detached task
        // so we don't block anything. This work is best-effort, we don't need to care if it fails.
        Task.detached {
            filteredURLs.forEach { url in
                AKTrace("\(baseID): Removing \(url) from \(cacheType) cache")
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func mkdir(ofType: CacheType, name: String) throws -> URL {
        let tempDir = urlForItem(cacheType: ofType, itemName: name)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cacheDropURL(_ url: URL) throws -> URL {
        let tempDir = try mkdir(ofType: .drop, name: UUID().uuidString)

        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        AKTrace("\(baseID): Drop-caching \(url) to \(tempURL)")
        try FileManager.default.copyItem(at: url, to: tempURL)

        return tempURL
    }

    func removeAll(ofType: CacheType) {
        if let cacheFolderURL = cacheURLs[ofType] {
            try? FileManager.default.removeItem(at: cacheFolderURL)
            try? FileManager.default.createDirectory(at: cacheFolderURL, withIntermediateDirectories: true)
        }
    }
}
