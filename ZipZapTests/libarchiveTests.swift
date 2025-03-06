//
//  libarchive.swift
//  ZipZapTests
//
//  Created by Chris Jones on 05/03/2025.
//

import Testing
import Foundation

@testable import ZipZap

@Suite("libarchive") class libarchiveTests {
    let archive: Archive
    let bundle: Bundle
    let url: URL?

    init() async throws{
        bundle = Bundle(for: libarchiveTests.self)
        url = bundle.url(forResource: "helloworld", withExtension: "zip")

        #expect(url != nil)

        let loader = libarchive(url: url!)
        archive = try await loader.loadArchive()
    }

    @Test func testArchiveProperties() async throws {
        // check the basic properties of Archive
        #expect(archive.URL == url)
        #expect(archive.name == "helloworld.zip")
        #expect(archive.format == .ZIP)
        #expect(archive.filters == [.None])
        #expect(archive.entries.count == 4)
        #expect(archive.canWrite == true)
    }

    @Test func testArchiveDirtyFlag() async throws {
        // test if dirtiness works
        #expect(archive.dirty == false)
        archive.setDirty()
        #expect(archive.dirty == true)
        archive.setDirty(false)
        #expect(archive.dirty == false)
    }

    @Test func testArchiveRoot() async throws {
        #expect(archive.root.type == .root)
        #expect(archive.root.path == ".")
        #expect(archive.root.source.type == .Root)
    }

    @Test func testArchiveOpenFail() async throws {
        let loader = libarchive(url: URL(filePath: "smb://lol")!)
        await #expect(throws: ArchiveError.self) {
            _ = try await loader.loadArchive()
        }
    }
}
