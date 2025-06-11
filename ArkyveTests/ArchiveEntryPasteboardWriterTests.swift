import Testing
import AppKit
@testable import Arkyve

@Suite("ArchiveEntryPasteboardWriter Tests")
final class ArchiveEntryPasteboardWriterTests {
//    func testInitialization() {
//        // Test initialization with entry
//        let source = ArchiveEntrySource(type: .Archive, pathInArchive: "/test/path")
//        let entry = ArchiveEntryExtractable(source: source, name: "test.txt", path: "/test/path/test.txt")
//        let writer = ArchiveEntryPasteboardWriter(entry: entry)
//        
//        #expect(writer.entry == entry)
//        #expect(writer.fileURLData == nil)
//    }
    
    func testInitializationWithFileURL() {
        // Test initialization with file URL data
        let url = URL(fileURLWithPath: "/test/path/file.txt")
        let data = try? NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: true)
        let writer = ArchiveEntryPasteboardWriter(fileURLData: data)
        
        #expect(writer.entry == nil)
        #expect(writer.fileURLData == data)
    }
    
    func testWritableTypes() {
        let writer = ArchiveEntryPasteboardWriter()
        let types = writer.writableTypes(for: NSPasteboard.general)
        
        #expect(types.contains(.archiveEntryExtractable))
        #expect(types.contains(.fileURL))
    }
    
//    func testPasteboardPropertyList() {
//        // Test with entry
//        let source = ArchiveEntrySource(type: .Archive, pathInArchive: "/test/path")
//        let entry = ArchiveEntryExtractable(source: source, name: "test.txt", path: "/test/path/test.txt")
//        let writer = ArchiveEntryPasteboardWriter(entry: entry)
//        
//        // Test archiveEntryExtractable type
//        let data = writer.pasteboardPropertyList(forType: .archiveEntryExtractable) as? Data
//        #expect(data != nil)
//        
//        // Test fileURL type
//        #expect(writer.pasteboardPropertyList(forType: .fileURL) == nil)
//        
//        // Test unknown type
//        #expect(writer.pasteboardPropertyList(forType: .string) == nil)
//    }
    
    func testPasteboardPropertyListWithFileURL() {
        // Test with file URL data
        let url = URL(fileURLWithPath: "/test/path/file.txt")
        let data = try? NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: true)
        let writer = ArchiveEntryPasteboardWriter(fileURLData: data)
        
        // Test fileURL type
        let returnedData = writer.pasteboardPropertyList(forType: .fileURL) as? Data
        #expect(returnedData == data)
        
        // Test archiveEntryExtractable type
        #expect(writer.pasteboardPropertyList(forType: .archiveEntryExtractable) == nil)
    }
} 
