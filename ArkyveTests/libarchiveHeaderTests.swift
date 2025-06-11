import Testing
@testable import Arkyve

@Suite("libarchiveHeader Tests")
final class libarchiveHeaderTests {
    func testInitialization() {
        let id = UUID()
        let source = ArchiveEntrySource(type: .Archive, pathInArchive: "/test/path")
        let type = ArchiveEntryType.file
        let path = "/test/path/file.txt"
        let name = "file.txt"
        let pathComponents = ["test", "path", "file.txt"]
        let size: Int64 = 1024
        let date = Date()
        let uid: Int64 = 501
        let gid: Int64 = 20
        let perms: mode_t = 0o644
        
        let header = libarchiveHeader(
            id: id,
            source: source,
            type: type,
            path: path,
            name: name,
            pathComponents: pathComponents,
            size: size,
            atime: date,
            ctime: date,
            mtime: date,
            btime: date,
            uid: uid,
            gid: gid,
            perms: perms
        )
        
        #expect(header.id == id)
        #expect(header.source == source)
        #expect(header.type == type)
        #expect(header.path == path)
        #expect(header.name == name)
        #expect(header.pathComponents == pathComponents)
        #expect(header.size == size)
        #expect(header.atime == date)
        #expect(header.ctime == date)
        #expect(header.mtime == date)
        #expect(header.btime == date)
        #expect(header.uid == uid)
        #expect(header.gid == gid)
        #expect(header.perms == perms)
        #expect(header.symlinkTarget == nil)
        #expect(header.rdev == nil)
    }
    
    func testSymlinkInitialization() {
        let header = libarchiveHeader(
            source: ArchiveEntrySource(type: .Archive, pathInArchive: "/test/link"),
            type: .symlink,
            path: "/test/link",
            name: "link",
            pathComponents: ["test", "link"],
            size: 0,
            atime: Date(),
            ctime: Date(),
            mtime: Date(),
            btime: Date(),
            uid: nil,
            gid: nil,
            perms: 0o777,
            symlinkTarget: "/test/target"
        )
        
        #expect(header.type == .symlink)
        #expect(header.symlinkTarget == "/test/target")
    }
    
    func testDeviceInitialization() {
        let header = libarchiveHeader(
            source: ArchiveEntrySource(type: .Archive, pathInArchive: "/dev/device"),
            type: .chardev,
            path: "/dev/device",
            name: "device",
            pathComponents: ["dev", "device"],
            size: 0,
            atime: Date(),
            ctime: Date(),
            mtime: Date(),
            btime: Date(),
            uid: nil,
            gid: nil,
            perms: 0o666,
            symlinkTarget: nil,
            rdev: 0x12345678
        )
        
        #expect(header.type == .chardev)
        #expect(header.rdev == 0x12345678)
    }
} 
