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
        AKTrace("Found in \(cacheTypes): \(found) for \(url)")
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
                AKTrace("Removing \(url) from \(cacheType) cache")
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func cacheDropURL(_ url: URL) throws -> URL {
        let tempDir = urlForItem(cacheType: .drop, itemName: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        AKTrace("Drop-caching \(url) to \(tempURL)")
        try FileManager.default.copyItem(at: url, to: tempURL)

        return tempURL
    }

//    func cacheSizes() -> (Int, Int, Int) {
//        let readCacheSize = cacheSize(cacheType: .read)
//        let dropCacheSize = cacheSize(cacheType: .drop)
//        let writeCacheSize = cacheSize(cacheType: .write)
//        return (readCacheSize, dropCacheSize, writeCacheSize)
//    }
//
//    func cacheSize(cacheType: CacheType) -> Int {
//        guard let cacheURL = urls[cacheType] else { return -1 }
//        return directorySize(url: cacheURL)
//    }
//
//    private func directorySize(url: URL) -> Int {
//        let contents: [URL]
//        do {
//            contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
//        } catch {
//            return 0
//        }
//
//        var size: Int = 0
//
//        for url in contents {
//            let isDirectoryResourceValue: URLResourceValues
//            do {
//                isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
//            } catch {
//                continue
//            }
//
//            if isDirectoryResourceValue.isDirectory == true {
//                size += directorySize(url: url)
//            } else {
//                let fileSizeResourceValue: URLResourceValues
//                do {
//                    fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
//                } catch {
//                    continue
//                }
//
//                size += fileSizeResourceValue.fileSize ?? 0
//            }
//        }
//        return size
//    }
}
