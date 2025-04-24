import Testing
@testable import Arkyve

@Suite("ArchiveEntrySourceType Tests")
final class ArchiveEntrySourceTypeTests {
    @Test("Test ArchiveEntrySourceType description")
    func testDescription() {
        #expect(ArchiveEntrySourceType.Archive.description == "Archive")
        #expect(ArchiveEntrySourceType.Filesystem.description == "Filesystem")
        #expect(ArchiveEntrySourceType.Root.description == "Root")
        #expect(ArchiveEntrySourceType.Synthetic.description == "Synthetic")
        #expect(ArchiveEntrySourceType.InMemory.description == "In Memory")
    }

    @Test("Test ArchiveEntrySourceType Codable conformance")
    func testCodable() throws {
        let types: [ArchiveEntrySourceType] = [.Archive, .Filesystem, .Root, .Synthetic, .InMemory]
        
        for type in types {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ArchiveEntrySourceType.self, from: encoded)
            #expect(decoded == type)
        }
    }
}

@Suite("ArchiveEntrySource Tests")
final class ArchiveEntrySourceTests {
    @Test("Test ArchiveEntrySource description")
    func testDescription() {
        let source = ArchiveEntrySource(type: .Archive, path: "/test/path")
        #expect(source.description == "Archive: /test/path")
    }

    @Test("Test ArchiveEntrySource Codable conformance")
    func testCodable() throws {
        let source = ArchiveEntrySource(type: .Filesystem, path: "/test/path")
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ArchiveEntrySource.self, from: encoded)
        
        #expect(decoded.type == source.type)
        #expect(decoded.path == source.path)
    }

    @Test("Test ArchiveEntrySource initialization")
    func testInitialization() {
        let source = ArchiveEntrySource(type: .InMemory, path: "memory://test")
        #expect(source.type == .InMemory)
        #expect(source.path == "memory://test")
    }
} 