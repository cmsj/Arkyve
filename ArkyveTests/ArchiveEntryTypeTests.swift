import Testing
import Foundation
@testable import Arkyve

@Suite("ArchiveEntryType Tests")
final class ArchiveEntryTypeTests {
    @Test("Initialization from mode_t values")
    func testModeTInitialization() {
        #expect(ArchiveEntryType(rawValue: S_IFREG) == .file)
        #expect(ArchiveEntryType(rawValue: S_IFDIR) == .directory)
        #expect(ArchiveEntryType(rawValue: S_IFSOCK) == .socket)
        #expect(ArchiveEntryType(rawValue: S_IFLNK) == .symlink)
        #expect(ArchiveEntryType(rawValue: S_IFCHR) == .chardev)
        #expect(ArchiveEntryType(rawValue: S_IFBLK) == .blockdev)
        #expect(ArchiveEntryType(rawValue: S_IFIFO) == .fifo)
        #expect(ArchiveEntryType(rawValue: 0) == .unknown) // Test unknown case
    }

    @Test("User string representation")
    func testUserString() {
        #expect(ArchiveEntryType.unknown.userString == "Unknown")
        #expect(ArchiveEntryType.file.userString == "File")
        #expect(ArchiveEntryType.directory.userString == "Folder")
        #expect(ArchiveEntryType.socket.userString == "Socket")
        #expect(ArchiveEntryType.symlink.userString == "Symlink")
        #expect(ArchiveEntryType.chardev.userString == "Char dev")
        #expect(ArchiveEntryType.blockdev.userString == "Block dev")
        #expect(ArchiveEntryType.fifo.userString == "FIFO")
        #expect(ArchiveEntryType.root.userString == "")
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in ArchiveEntryType.allCases {
            let encoded = try encoder.encode(type)
            let decoded = try decoder.decode(ArchiveEntryType.self, from: encoded)
            #expect(decoded == type)
        }
    }
}
