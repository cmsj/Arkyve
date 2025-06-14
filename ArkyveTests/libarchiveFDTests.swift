import Testing
import Foundation
@testable import Arkyve

@Suite("libarchiveFD Tests")
final class libarchiveFDTests {
    @Test func testInitialState() {
        let fd = libarchiveFD()
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
        #expect(fd.type == .read)
        #expect(fd.writeCacheURL == nil)
    }
    
    @Test func testCloseOnUninitialized() {
        var fd = libarchiveFD()
        fd.close() // Should not crash
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
    }
    
    @Test func testOpenReadWithInvalidPath() {
        var fd = libarchiveFD()
        #expect(throws: ArkyveError.self) {
            try fd.openRead(path: "/nonexistent/path")
        }
    }
    
    @Test func testOpenReadWithValidPath() async {
        // Create a temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test1.tar")

        // Create a simple tar file for testing
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["cf", testFile.path, "-C", tempDir.path, "."]
        try? process.run()
        process.waitUntilExit()
        
        var fd = libarchiveFD()
        try? fd.openRead(path: testFile.path)
        #expect(fd.fd >= 0)
        #expect(fd.archive != nil)
        #expect(fd.type == .read)

        fd.close()
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    @Test func testOpenWriteWithInvalidPath() {
        var fd = libarchiveFD(type: .write)
        #expect(throws: ArkyveError.self) {
            try fd.openWrite(at: URL(fileURLWithPath: "/nonexistent/path/test2.tar"), format: .TAR_PAX_RESTRICTED, filters: [.None])
        }
    }
    
    @Test func testOpenWriteWithValidPath() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test3.tar")
        
        var fd = libarchiveFD(type: .write)
        try? fd.openWrite(at: testFile, format: .TAR_PAX_RESTRICTED, filters: [.None])
        #expect(fd.fd == -1) //openWrite doesn't use file descriptors
        #expect(fd.archive != nil)
        #expect(fd.type == .write)

        fd.close()
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
} 
