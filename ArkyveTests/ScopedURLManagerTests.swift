import Testing
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
    
    func testInitialization() {
        // Test initialization properties
        #expect(urlManager.baseID == testUUID)
        #expect(urlManager.urlStore.withLock { $0.isEmpty })
        #expect(urlManager.options.contains(.withSecurityScope))
        #expect(urlManager.options.contains(.securityScopeAllowOnlyReadAccess))
        #expect(urlManager.options.contains(.withoutImplicitSecurityScope))
    }
    
    func testDropSBM() {
        // Test the static dropSBM instance
        let dropSBM = ScopedURLManager.dropSBM
        #expect(dropSBM.baseID != testUUID) // Should have a different UUID
        #expect(dropSBM.urlStore.withLock { $0.isEmpty })
    }
    
    func testStoreURLs() throws {
        // Create test URLs
        let url1 = URL(fileURLWithPath: "/test/path1")
        let url2 = URL(fileURLWithPath: "/test/path2")
        
        // Test storing URLs
        try urlManager.store([url1, url2], forOperation: .openArchive)
        
        // Verify stored URLs
        #expect(urlManager.urlStore.withLock { $0.count == 2 })
        #expect(urlManager.urlStore.withLock { $0[0].url == url1 })
        #expect(urlManager.urlStore.withLock { $0[1].url == url2 })
    }
    
    func testClear() {
        // Add some URLs
        let url1 = URL(fileURLWithPath: "/test/path1")
        let url2 = URL(fileURLWithPath: "/test/path2")
        
        try? urlManager.store([url1, url2], forOperation: .openArchive)
        #expect(urlManager.urlStore.withLock { $0.count == 2 })

        // Clear and verify
        urlManager.clear()
        #expect(urlManager.urlStore.withLock { $0.isEmpty })
    }
} 
