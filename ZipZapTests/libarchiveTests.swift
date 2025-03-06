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

    @Test func testOpenArchive() async throws {
        let bundle = Bundle(for: libarchiveTests.self)
        let url = bundle.url(forResource: "helloworld", withExtension: "zip")

        #expect(url != nil)

        let loader = libarchive(url: url!)
        let archive = try await loader.loadArchive()

        #expect(archive.URL == url)
        #expect(archive.format == .ZIP)
        #expect(archive.entries.count == 4)
    }
}
