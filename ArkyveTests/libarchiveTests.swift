//
//  libarchive.swift
//  ArkyveTests
//
//  Created by Chris Jones on 05/03/2025.
//

import Testing
import Foundation

@testable import Arkyve

@Suite("libarchive") class libarchiveTests {
    let archive: Archive
    let bundle: Bundle
    let url: URL?

    init() async throws {
        bundle = Bundle(for: libarchiveTests.self)
        url = bundle.url(forResource: "helloworld", withExtension: "zip")

        #expect(url != nil)

        archive = try await libarchiveWrapper.loadArchive(at: url!)
    }

    @Test func testArchiveProperties() async throws {
        // check the basic properties of Archive
        #expect(archive.URL == url)
        #expect(archive.name == "helloworld.zip")
        #expect(archive.format == .ZIP)
        #expect(archive.filters == [.None])
        #expect(archive.entries.count == 4)
    }

    @Test func testArchiveDirtyFlag() async throws {
        // test if dirtiness works
        #expect(archive.dirty == false)
        archive.setDirty()
        #expect(archive.dirty == true)
        archive.setDirty(false)
        #expect(archive.dirty == false)
        archive.setDirty()
        #expect(archive.dirty == true)
        archive.setClean()
        #expect(archive.dirty == false)
    }

    @Test func testArchiveRoot() async throws {
        #expect(archive.root.type == .root)
        #expect(archive.root.path == "")
        #expect(archive.root.source.type == .Root)
    }

    @Test func testArchiveOpenFail() async throws {
        let loader = libarchiveWrapper(url: URL(filePath: "smb://lol")!)
        await #expect(throws: ArkyveError.self) {
            _ = try await loader.loadArchive()
        }
    }

    // MARK: - libarchiveFilter Tests
    
    @Test func testLibarchiveFilterDescription() async {
        #expect(libarchiveFilter.None.description == "None")
        #expect(libarchiveFilter.GZip.description == "GZip")
        #expect(libarchiveFilter.BZip2.description == "BZip2")
        #expect(libarchiveFilter.Compress.description == "Compress")
        #expect(libarchiveFilter.Program.description == "Program")
        #expect(libarchiveFilter.LZMA.description == "LZMA")
        #expect(libarchiveFilter.XZ.description == "XZ")
        #expect(libarchiveFilter.UU.description == "UU")
        #expect(libarchiveFilter.RPM.description == "RPM")
        #expect(libarchiveFilter.LZIP.description == "LZIP")
        #expect(libarchiveFilter.LRZIP.description == "LRZIP")
        #expect(libarchiveFilter.LZOP.description == "LZOP")
        #expect(libarchiveFilter.GRZIP.description == "GRZIP")
        #expect(libarchiveFilter.LZ4.description == "LZ4")
        #expect(libarchiveFilter.ZSTD.description == "ZSTD")
    }
    
    @Test func testLibarchiveFilterIdentifiable() async {
        let filter = libarchiveFilter.GZip
        #expect(filter.id == filter.rawValue)
    }
    
    // MARK: - libarchiveFormat Tests
    
    @Test func testLibarchiveFormatDescription() async {
        #expect(libarchiveFormat.Unknown.description == "Unknown")
        #expect(libarchiveFormat.CPIO.description == "CPIO")
        #expect(libarchiveFormat.TAR.description == "BSD tar")
        #expect(libarchiveFormat.TAR_GNUTAR.description == "tar")
        #expect(libarchiveFormat.ZIP.description == "Zip")
        #expect(libarchiveFormat._7ZIP.description == "7Zip")
    }
    
    @Test func testLibarchiveFormatComparable() async {
        #expect(libarchiveFormat.Unknown < libarchiveFormat.CPIO)
        #expect(libarchiveFormat.CPIO < libarchiveFormat.TAR)
        #expect(libarchiveFormat.TAR < libarchiveFormat.ZIP)
    }
    
    @Test func testLibarchiveFormatIdentifiable() async {
        let format = libarchiveFormat.ZIP
        #expect(format.id == format.rawValue)
    }
    
    // MARK: - libarchiveHeader Tests
    
    @Test func testLibarchiveHeaderInitialization() async {
        let source = ArchiveEntrySource(type: .Archive, path: "/test/path")
        let header = libarchiveHeader(
            source: source,
            type: .file,
            path: "/test/path/file.txt",
            name: "file.txt",
            pathComponents: ["test", "path", "file.txt"],
            size: 1024,
            atime: Date(),
            ctime: Date(),
            mtime: Date(),
            btime: Date(),
            uid: 501,
            gid: 20,
            perms: 0o644
        )
        
        #expect(header.source.type == .Archive)
        #expect(header.source.path == "/test/path")
        #expect(header.type == .file)
        #expect(header.path == "/test/path/file.txt")
        #expect(header.name == "file.txt")
        #expect(header.pathComponents == ["test", "path", "file.txt"])
        #expect(header.size == 1024)
        #expect(header.uid == 501)
        #expect(header.gid == 20)
        #expect(header.perms == 0o644)
    }
    
    // MARK: - libarchiveFD Tests
    
    @Test func testLibarchiveFDInitialization() async {
        let fd = libarchiveFD()
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
        #expect(fd.type == .read)
        #expect(fd.writeCacheURL == nil)
    }
    
    @Test func testLibarchiveFDClose() async {
        var fd = libarchiveFD()
        fd.close()
        #expect(fd.fd == -1)
        #expect(fd.archive == nil)
    }
    
    // MARK: - libarchiveWrapper Tests
    
    @Test func testLibarchiveWrapperInitialization() async {
        let url = URL(fileURLWithPath: "/test/archive.zip")
        let wrapper = libarchiveWrapper(url: url)
        #expect(await wrapper.testURL() == url)
    }
    
    @Test func testLibarchiveWrapperPath() async {
        let url = URL(fileURLWithPath: "/test/archive.zip")
        let wrapper = libarchiveWrapper(url: url)
        #expect(await wrapper.testPath() == "/test/archive.zip")
    }
    
    @Test func testLibarchiveWrapperPathWithPercentEncoding() async {
        let url = URL(fileURLWithPath: "/test/archive%20with%20spaces.zip")
        let wrapper = libarchiveWrapper(url: url)
        #expect(await wrapper.testPath() == "/test/archive with spaces.zip")
    }

//    @Test func testLibarchiveWrapperExtractEntries() async throws {
//        let testURL = URL(fileURLWithPath: "/tmp/test_extract")
//        let wrapper = libarchiveWrapper(url: url!)
//        
//        // Create test directory
//        try FileManager.default.createDirectory(at: testURL, withIntermediateDirectories: true)
//        defer { try? FileManager.default.removeItem(at: testURL) }
//        
//        // Extract all entries
//        let entries = archive.entries.filter { !$0.isSynthesized }
//        let extractableEntries = entries.map { ArchiveEntryExtractable(from: [$0]) }
//        
//        let writtenURLs = try await wrapper.extractEntries(extractableEntries, toFolder: testURL)
//        #expect(writtenURLs.count == entries.count)
//        
//        // Verify files were extracted
//        for entry in entries {
//            let extractedPath = testURL.appendingPathComponent(entry.path)
//            #expect(FileManager.default.fileExists(atPath: extractedPath.path))
//        }
//    }

//    @Test func testLibarchiveWrapperWriteArchive() async throws {
//        let outputURL = URL(fileURLWithPath: "/tmp/test_write.zip")
//        let wrapper = libarchiveWrapper(url: url!)
//        
//        // Create a header map from existing entries
//        var headerMap: [String: ArchiveEntryFlat] = [:]
//        for entry in archive.entries {
//            headerMap[entry.path] = ArchiveEntryFlat(entry: entry)
//        }
//        
//        // Write the archive
//        try await wrapper.writeArchive(
//            headerMap: headerMap,
//            to: outputURL,
//            format: .ZIP,
//            filters: [.None]
//        )
//        
//        // Verify the archive was created
//        #expect(FileManager.default.fileExists(atPath: outputURL.path))
//        
//        // Clean up
//        try? FileManager.default.removeItem(at: outputURL)
//    }

//    @Test func testLibarchiveWrapperExtractWithRetainFullPath() async throws {
//        let testURL = URL(fileURLWithPath: "/tmp/test_extract_fullpath")
//        let wrapper = libarchiveWrapper(url: url!)
//        
//        // Create test directory
//        try FileManager.default.createDirectory(at: testURL, withIntermediateDirectories: true)
//        defer { try? FileManager.default.removeItem(at: testURL) }
//        
//        // Extract entries with retainFullPath
//        let entries = archive.entries.filter { !$0.isSynthesized }
//        let extractableEntries = entries.map {
//            ArchiveEntryExtractable(archiveURL: testURL, cacheURL: nil, selectedPath: "", id: $0.id, entries: [$0.flatSelf()])
//        }
//
//        let writtenURLs = try await wrapper.extractEntries(
//            extractableEntries,
//            toFolder: testURL,
//            retainFullPath: true
//        )
//        #expect(writtenURLs.count == entries.count)
//        
//        // Verify files were extracted with full paths
//        for entry in entries {
//            let extractedPath = testURL.appendingPathComponent(entry.path)
//            #expect(FileManager.default.fileExists(atPath: extractedPath.path))
//        }
//    }
}
