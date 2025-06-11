import Testing
import Foundation
@testable import Arkyve

@Suite("CacheManager Tests")
final class CacheManagerTests {
    let testUUID = UUID()
    var cacheManager: CacheManager!
    var testFileURL: URL?

    init() {
        cacheManager = CacheManager(for: testUUID)
        // Create a test file in the read cache
        let fileURL = cacheManager.urlForItem(cacheType: .read, itemName: "testfile.txt")
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8))
        testFileURL = fileURL
    }

    deinit {
        cacheManager.removeCacheDirectories()
        cacheManager = nil
        testFileURL = nil
    }

    @Test func testInitialization() {
        #expect(cacheManager.baseID == testUUID)
        for cacheType in CacheType.allCases {
            let url = cacheManager.cacheURLs[cacheType]
            #expect(url != nil)
            #expect(FileManager.default.fileExists(atPath: url!.path))
        }
    }

    @Test func testUrlForItem() {
        let url = cacheManager.urlForItem(cacheType: .read, itemName: "foo.txt")
        #expect(url.lastPathComponent == "foo.txt")
        #expect(url.path.contains("read-cache"))
    }

    @Test func testIsInCache() {
        precondition(testFileURL != nil)
        #expect(cacheManager.isInCache(url: testFileURL!, [.read]))
        #expect(!cacheManager.isInCache(url: testFileURL!, [.write]))
    }

    @Test func testIsInDropCache() {
        precondition(testFileURL != nil)
        let dropURL = cacheManager.urlForItem(cacheType: .drop, itemName: "dropfile.txt")
        #expect(!cacheManager.isInDropCache(url: testFileURL!))
        #expect(cacheManager.isInDropCache(url: dropURL))
    }

    @Test func testRemoveCacheItems() async throws {
        let fileURL = cacheManager.urlForItem(cacheType: .write, itemName: "toremove.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("remove".utf8))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        cacheManager.removeCacheItems(cacheType: .write, urls: [fileURL])
        // Wait for detached task to finish
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func testCacheDropURL() throws {
        // Create a temp file to copy
        let tempDir = FileManager.default.temporaryDirectory
        let srcURL = tempDir.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: srcURL.path, contents: Data("dropme".utf8))
        let dropURL = try cacheManager.cacheDropURL(srcURL)
        #expect(FileManager.default.fileExists(atPath: dropURL.path))
        // Clean up
        try? FileManager.default.removeItem(at: srcURL)
        try? FileManager.default.removeItem(at: dropURL.deletingLastPathComponent())
    }
} 
