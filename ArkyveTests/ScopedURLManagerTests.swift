import Testing
import Foundation
@testable import Arkyve

@Suite("ScopedURLManager Tests")
final class ScopedURLManagerTests {
    var urlManager: ScopedURLManager!
    let testUUID = UUID()
    
    init() {
        urlManager = ScopedURLManager(for: testUUID)
    }
    
    deinit {
        urlManager = nil
    }
    
    @Test("Initial state")
    func testInitialState() {
        #expect(urlManager.baseID == testUUID)
        #expect(urlManager.urlStore.withLock { $0.isEmpty })
        #expect(urlManager.options.contains(.withSecurityScope))
    }
    
    @Test("Static dropSBM instance")
    func testDropSBM() {
        let dropSBM = ScopedURLManager.dropSBM
        #expect(dropSBM.baseID != testUUID) // Should have a different UUID
        #expect(dropSBM.urlStore.withLock { $0.isEmpty })
    }
// FIXME: Figure out how to test these things when they don't have legit bookmark data
//    @Test("Store single URL")
//    func testStoreSingleURL() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
//
//        try urlManager.store(testURL, forOperation: .openArchive)
//
//        #expect(urlManager.urlStore.withLock { $0.count == 1 })
//        #expect(urlManager.urlStore.withLock { $0[0].url == testURL })
//    }
//    
//    @Test("Store multiple URLs")
//    func testStoreMultipleURLs() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let url1 = bundle.url(forResource: "hello", withExtension: "txt")!
//        let url2 = bundle.url(forResource: "test", withExtension: "txt")!
//
//        try urlManager.store([url1, url2], forOperation: .openArchive)
//
//        #expect(urlManager.urlStore.withLock { $0.count == 2 })
//        #expect(urlManager.urlStore.withLock { $0[0].url == url1 })
//        #expect(urlManager.urlStore.withLock { $0[1].url == url2 })
//    }
//    
//    @Test("Store duplicate URL")
//    func testStoreDuplicateURL() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
//
//        try urlManager.store(testURL, forOperation: .openArchive)
//        try urlManager.store(testURL, forOperation: .openArchive) // Should not add duplicate
//
//        #expect(urlManager.urlStore.withLock { $0.count == 1 })
//        #expect(urlManager.urlStore.withLock { $0[0].url == testURL })
//    }
//    
//    @Test("Remove URL")
//    func testRemoveURL() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
//
//        try urlManager.store(testURL, forOperation: .openArchive)
//        #expect(urlManager.urlStore.withLock { $0.count == 1 })
//        
//        urlManager.remove(testURL)
//        #expect(urlManager.urlStore.withLock { $0.isEmpty })
//    }
//    
//    @Test("Clear all URLs")
//    func testClear() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let url1 = bundle.url(forResource: "hello", withExtension: "txt")!
//        let url2 = bundle.url(forResource: "test", withExtension: "txt")!
//
//        try urlManager.store([url1, url2], forOperation: .openArchive)
//        #expect(urlManager.urlStore.withLock { $0.count == 2 })
//        
//        urlManager.clear()
//        #expect(urlManager.urlStore.withLock { $0.isEmpty })
//    }
//    
//    @Test("Bookmark scoped URL")
//    func testBookmarkScopedURL() throws {
//        let bundle = Bundle(for: ArchiveEntryTests.self)
//        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
//        try urlManager.store(testURL, forOperation: .openArchive)
//        let scopedURL = try urlManager.bookmarkScopedURL(testURL, forOperation: .unknown)
//
//        #expect(scopedURL == testURL)
//    }
    
    @Test("Bookmark scoped URL not found")
    func testBookmarkScopedURLNotFound() {
        let testURL = URL(fileURLWithPath: "/test/path")

        #expect(throws: ArkyveError.self) {
            try self.urlManager.bookmarkScopedURL(testURL, forOperation: .unknown)
        }
    }
} 
