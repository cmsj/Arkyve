import Testing
import Foundation
@testable import Arkyve

@Suite("ArchiveEntryFlat Tests")
final class ArchiveEntryFlatTests {
    @Test("Initialization with basic properties")
    func testInitialization() {
        let path = "test/file.txt"
        let isSynthesized = false
        let header = libarchiveHeader(source: ArchiveEntrySource(type: .Filesystem, pathInArchive: path),
                                    type: .file,
                                    path: path,
                                    name: "file.txt",
                                    pathComponents: ["test", "file.txt"],
                                    size: 1024,
                                    atime: Date(),
                                    ctime: Date(),
                                    mtime: Date(),
                                    btime: Date(),
                                    uid: 501,
                                    gid: 20,
                                    perms: 0o644,
                                    symlinkTarget: nil,
                                    rdev: 0)
        let source = ArchiveEntrySource(type: .Filesystem, pathInArchive: path)
        
        let flatEntry = ArchiveEntryFlat(path: path,
                                       isSynthesized: isSynthesized,
                                       header: header,
                                       source: source)
        
        #expect(flatEntry.path == path)
        #expect(flatEntry.isSynthesized == isSynthesized)
        #expect(flatEntry.header.path == path)
        #expect(flatEntry.source.type == .Filesystem)
    }
    
    @Test("File manager attributes")
    func testFileManagerAttributes() {
        let path = "test/file.txt"
        let now = Date()
        let header = libarchiveHeader(source: ArchiveEntrySource(type: .Filesystem, pathInArchive: path),
                                    type: .file,
                                    path: path,
                                    name: "file.txt",
                                    pathComponents: ["test", "file.txt"],
                                    size: 1024,
                                    atime: now,
                                    ctime: now,
                                    mtime: now,
                                    btime: now,
                                    uid: 501,
                                    gid: 20,
                                    perms: 0o644,
                                    symlinkTarget: nil,
                                    rdev: 0)
        let source = ArchiveEntrySource(type: .Filesystem, pathInArchive: path)
        
        let flatEntry = ArchiveEntryFlat(path: path,
                                       isSynthesized: false,
                                       header: header,
                                       source: source)
        
        let attributes = flatEntry.fileManagerAttributes
        
        #expect(attributes[.creationDate] as? Date == now)
        #expect(attributes[.modificationDate] as? Date == now)
        #expect(attributes[.posixPermissions] as? NSNumber == 0o644 as NSNumber)
    }
    
    @Test("Synthesized directory entry")
    func testSynthesizedDirectory() {
        let path = "test/dir"
        let header = libarchiveHeader(source: ArchiveEntrySource(type: .Synthetic, pathInArchive: path),
                                    type: .directory,
                                    path: path,
                                    name: "dir",
                                    pathComponents: ["test", "dir"],
                                    size: -1,
                                    atime: Date(),
                                    ctime: Date(),
                                    mtime: Date(),
                                    btime: Date(),
                                    uid: 501,
                                    gid: 20,
                                    perms: 0o755,
                                    symlinkTarget: nil,
                                    rdev: 0)
        let source = ArchiveEntrySource(type: .Synthetic, pathInArchive: path)
        
        let flatEntry = ArchiveEntryFlat(path: path,
                                       isSynthesized: true,
                                       header: header,
                                       source: source)
        
        #expect(flatEntry.isSynthesized == true)
        #expect(flatEntry.header.type == .directory)
        #expect(flatEntry.source.type == .Synthetic)
    }
    
    @Test("Symlink entry")
    func testSymlinkEntry() {
        let path = "test/link"
        let target = "target/file.txt"
        let header = libarchiveHeader(source: ArchiveEntrySource(type: .Filesystem, pathInArchive: path),
                                    type: .symlink,
                                    path: path,
                                    name: "link",
                                    pathComponents: ["test", "link"],
                                    size: -1,
                                    atime: Date(),
                                    ctime: Date(),
                                    mtime: Date(),
                                    btime: Date(),
                                    uid: 501,
                                    gid: 20,
                                    perms: 0o755,
                                    symlinkTarget: target,
                                    rdev: 0)
        let source = ArchiveEntrySource(type: .Filesystem, pathInArchive: path)
        
        let flatEntry = ArchiveEntryFlat(path: path,
                                       isSynthesized: false,
                                       header: header,
                                       source: source)
        
        #expect(flatEntry.header.type == .symlink)
        #expect(flatEntry.header.symlinkTarget == target)
    }
} 