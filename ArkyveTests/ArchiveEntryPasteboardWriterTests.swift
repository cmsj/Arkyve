import Testing
import AppKit
@testable import Arkyve

@Suite("ArchiveEntryPasteboardWriter Tests")
final class ArchiveEntryPasteboardWriterTests {
    @Test func testInitialization() {
        // Test initialization with entry
        let entry = ArchiveEntry(isRoot: true)
        let entryExtractable = entry.asExtractable(from: nil, cacheURL: URL(fileURLWithPath: "/dev/null"), vmID: UUID())
        let writer = ArchiveEntryPasteboardWriter(entry: entryExtractable)
        
        #expect(writer.entry?.name == entryExtractable.name)
        #expect(writer.fileURLData == nil)
    }
    
    @Test func testInitializationWithFileURL() {
        // Test initialization with file URL data
        let url = URL(fileURLWithPath: "/test/path/file.txt")
        let data = try? NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: true)
        let writer = ArchiveEntryPasteboardWriter(fileURLData: data)
        
        #expect(writer.entry == nil)
        #expect(writer.fileURLData == data)
    }
    
    @Test func testWritableTypes() {
        let writer = ArchiveEntryPasteboardWriter()
        let types = writer.writableTypes(for: NSPasteboard.general)
        
        #expect(types.contains(.archiveEntryExtractable))
        #expect(types.contains(.fileURL))
    }
    
    @Test func testPasteboardPropertyList() {
        // Test with entry
        let entry = ArchiveEntry(isRoot: true).asExtractable(from: nil, cacheURL: URL(fileURLWithPath: "/dev/null"), vmID: UUID())
        let writer = ArchiveEntryPasteboardWriter(entry: entry)
        
        // Test archiveEntryExtractable type
        let data = writer.pasteboardPropertyList(forType: .archiveEntryExtractable) as? Data
        let decoder = JSONDecoder()
        let decodedObject = try? decoder.decode(ArchiveEntryExtractable.self, from: data!)
        #expect(decodedObject != nil)
        #expect(decodedObject?.name == entry.name)

        // Test fileURL type
        #expect(writer.pasteboardPropertyList(forType: .fileURL) == nil)
        
        // Test unknown type
        #expect(writer.pasteboardPropertyList(forType: .string) == nil)
    }
    
    @Test func testPasteboardPropertyListWithFileURL() {
        // Test with file URL data
        let url = URL(fileURLWithPath: "/test/path/file.txt")
        let data = try? NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: true)
        let writer = ArchiveEntryPasteboardWriter(fileURLData: data)
        
        // Test fileURL type
        let returnedData = writer.pasteboardPropertyList(forType: .fileURL) as? Data
        #expect(returnedData == data)
    }
} 
