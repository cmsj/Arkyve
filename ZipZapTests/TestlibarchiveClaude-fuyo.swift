//
//  TestlibarchiveClaude.swift
//  ZipZap
//
//  Created by Chris Jones on 10/03/2025.
//

import Testing
import Foundation
@testable import ZipZap // Assuming your module is named ZipZap

@Suite("libarchiveTests", .serialized)
struct libarchiveTestsClaudeFuyo {

    // MARK: - Test Helpers

    /// Gets a test archive from the bundle
    func getTestArchive(named name: String) throws -> URL {
        let bundle = Bundle(for: libarchiveTests.self)
        guard let bundleURL = bundle.url(forResource: name, withExtension: nil) else {
            throw TestError("Test archive \(name) not found in bundle")
        }

        // Copy to a temporary location so we can modify it if needed
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(name)

        try FileManager.default.copyItem(at: bundleURL, to: tempURL)

        return tempURL
    }

    /// Cleans up temporary files after tests
    func cleanupTestFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Creates a temporary directory for extraction
    func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    // MARK: - Tests

//    @Test("Initialize libarchive")
//    func testInitialization() throws {
//        let testURL = URL(fileURLWithPath: "/path/to/archive.zip")
//        let archive = libarchive(url: testURL)
//
//        #expect(archive.url == testURL)
//    }

    @Test("Read archive entries, format, and filters")
    func testReadEntriesFormatFilters() async throws {
        // Get test archive from bundle
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Test reading entries, format, and filters
        let (format, filters, headers) = try await archive.readEntriesFormatFilters()

        // Verify format is recognized
        #expect(format != .Unknown)

        // Verify we have at least one filter
        #expect(!filters.isEmpty)

        // Verify we have at least one entry
        #expect(!headers.isEmpty)

        // Verify the entries have the expected properties
        for entry in headers {
            #expect(entry.source.type == .Archive)
            #expect(entry.path != "Unknown")
            #expect(!entry.pathComponents.isEmpty)
        }
    }

    @Test("Load archive")
    func testLoadArchive() async throws {
        // Get test archive from bundle
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Test loading the archive
        let loadedArchive = try await archive.loadArchive()

        // Verify the loaded archive has the expected properties
        #expect(loadedArchive.URL == archiveURL)
        #expect(loadedArchive.root != nil)
        #expect(loadedArchive.entries.count > 0)
        #expect(loadedArchive.format != .Unknown)
        #expect(!loadedArchive.filters.isEmpty)
    }

    @Test("Extract entries")
    func testExtractEntries() async throws {
        // Get test archive from bundle
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Load the archive to get entries
        let loadedArchive = try await archive.loadArchive()

        // Create a temporary directory for extraction
        let extractDir = try createTempDirectory()
        defer { cleanupTestFiles([extractDir]) }

        // Prepare extractable entries
        let extractable = loadedArchive.root.asExtractable(for: loadedArchive)

        // Test extracting entries
        let extractedURLs = try await archive.extractEntries([extractable], toFolder: extractDir)

        // Verify extraction results
        #expect(!extractedURLs.isEmpty)
        #expect(extractedURLs.count == 5)

        // Check that files were actually extracted
        for url in extractedURLs {
            let exists = FileManager.default.fileExists(atPath: url.path)
            #expect(exists)
        }
    }

    @Test("Extract entries with path retention")
    func testExtractEntriesWithPathRetention() async throws {
        // Get test archive from bundle
        let archiveURL = try getTestArchive(named: "test_archive_nested.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Load the archive to get entries
        let loadedArchive = try await archive.loadArchive()

        // Create a temporary directory for extraction
        let extractDir = try createTempDirectory()
        defer { cleanupTestFiles([extractDir]) }

        // Prepare extractable entries
        let extractable = loadedArchive.root.asExtractable(for: loadedArchive)

        // Test extracting entries with path retention
        let extractedURLs = try await archive.extractEntries([extractable], toFolder: extractDir, retainFullPath: true)

        // Verify extraction results
        #expect(!extractedURLs.isEmpty)

        // Check that files were extracted with full paths
        for url in extractedURLs {
            let exists = FileManager.default.fileExists(atPath: url.path)
            #expect(exists)
        }

        // Verify directory structure was preserved
        let nestedDirs = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        #expect(nestedDirs.count > 0)

        // Check for nested directories
        var foundNestedDir = false
        for url in nestedDirs {
            if url.hasDirectoryPath {
                foundNestedDir = true
                break
            }
        }
        #expect(foundNestedDir)
    }

    @Test("Write archive")
    func testWriteArchive() async throws {
        // Get test archive from bundle
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Load the archive to get entries
        let loadedArchive = try await archive.loadArchive()

        // Create a new destination for the written archive
        let newArchiveURL = FileManager.default.temporaryDirectory.appendingPathComponent("new_test_archive.zip")
        defer { cleanupTestFiles([newArchiveURL]) }

        // Create a header map from the flat entries
        let flatEntries = loadedArchive.root.flatChildren()
        var headerMap: [String: ArchiveEntryFlat] = [:]
        for entry in flatEntries {
            headerMap[entry.path] = entry
        }

        // Test writing the archive
        try await archive.writeArchive(
            headerMap: headerMap,
            to: newArchiveURL,
            format: loadedArchive.format,
            filters: loadedArchive.filters
        )

        // Verify the new archive was created
        let exists = FileManager.default.fileExists(atPath: newArchiveURL.path)
        #expect(exists)

        // Verify the new archive can be read
        let newArchiveLib = libarchiveWrapper(url: newArchiveURL)
        let (format, filters, headers) = try await newArchiveLib.readEntriesFormatFilters()

        // Verify the new archive has the expected format, filters, and entries
        #expect(format == loadedArchive.format)
        #expect(filters.count == loadedArchive.filters.count)

        // The count might be different due to synthetic entries, so we'll check that we have entries
        #expect(!headers.isEmpty)
    }

    @Test("Test different archive formats")
    func testDifferentArchiveFormats() async throws {
        // Test with different archive formats from the bundle
        let archiveFormats = [
            "helloworld.zip",
            "helloworld.tar.gz"
        ]

        for formatName in archiveFormats {
            do {
                let archiveURL = try getTestArchive(named: formatName)
                defer { cleanupTestFiles([archiveURL]) }

                let archive = libarchiveWrapper(url: archiveURL)

                // Test reading entries, format, and filters
                let (format, filters, headers) = try await archive.readEntriesFormatFilters()

                // Verify format is recognized
                #expect(format != .Unknown)

                // Verify we have entries
                #expect(!headers.isEmpty)

                // Verify format matches filename extension
                if formatName.hasSuffix(".zip") {
                    #expect(format == .ZIP)
                } else if formatName.hasSuffix(".tar") {
                    #expect(format == .TAR)
                } else if formatName.hasSuffix(".tar.gz") {
                    #expect(format == .TAR_PAX_INTERCHANGE)
                    #expect(filters.contains(.GZip))
                } else if formatName.hasSuffix(".7z") {
                    #expect(format == ._7ZIP)
                }
            }// catch {
                // Skip formats that aren't supported
//                print("Skipping unsupported format: \(formatName)")
//            }
        }
    }

    @Test("Read date helper method")
    func testReadDate() async throws {
        // This is a private method, so we'll test it indirectly through the public API
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Read entries which will use the readDate method internally
        let (_, _, headers) = try await archive.readEntriesFormatFilters()

        // Verify dates were read
        for entry in headers {
            // At least one of these dates should be non-zero for real files
            let hasValidDate = entry.atime != Date(since: 0) ||
            entry.ctime != Date(since: 0) ||
            entry.mtime != Date(since: 0) ||
            entry.btime != Date(since: 0)

            #expect(hasValidDate)
        }
    }

    @Test("Entry path helper method")
    func testEntryPath() async throws {
        // This is a private method, so we'll test it indirectly through the public API
        let archiveURL = try getTestArchive(named: "helloworld.zip")
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchiveWrapper(url: archiveURL)

        // Read entries which will use the entryPath method internally
        let (_, _, headers) = try await archive.readEntriesFormatFilters()

        // Verify paths were read
        for entry in headers {
            #expect(!entry.path.isEmpty)
            #expect(entry.path != "Unknown")

            // Verify trailing slashes were removed
            #expect(entry.path.last != "/")
        }
    }

    @Test("Error handling for non-existent archive")
    func testErrorHandlingForNonExistentArchive() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/path/to/nonexistent.zip")
        let archive = libarchiveWrapper(url: nonExistentURL)

        // Attempt to read a non-existent archive should throw an error
        do {
            _ = try await archive.readEntriesFormatFilters()
            #expect(false, "Expected an error but none was thrown")
        } catch {
            #expect(error is ArchiveError)
        }

        // Attempt to load a non-existent archive should throw an error
        do {
            _ = try await archive.loadArchive()
            #expect(false, "Expected an error but none was thrown")
        } catch {
            #expect(error is ArchiveError)
        }
    }

    @Test("Error handling for invalid archive")
    func testErrorHandlingForInvalidArchive() async throws {
        // Create a text file that's not a valid archive
        let tempDir = FileManager.default.temporaryDirectory
        let invalidArchiveURL = tempDir.appendingPathComponent("invalid_archive.zip")
        try "This is not a valid archive".write(to: invalidArchiveURL, atomically: true, encoding: .utf8)
        defer { cleanupTestFiles([invalidArchiveURL]) }

        let archive = libarchiveWrapper(url: invalidArchiveURL)

        // Attempt to read an invalid archive should throw an error
        do {
            _ = try await archive.readEntriesFormatFilters()
            #expect(false, "Expected an error but none was thrown")
        } catch {
            #expect(error is ArchiveError)
        }

        // Attempt to load an invalid archive should throw an error
        do {
            _ = try await archive.loadArchive()
            #expect(false, "Expected an error but none was thrown")
        } catch {
            #expect(error is ArchiveError)
        }
    }

//    @Test("Extract specific entries")
//    func testExtractSpecificEntries() async throws {
//        // Get test archive from bundle
//        let archiveURL = try getTestArchive(named: "test_archive_nested.zip")
//        defer { cleanupTestFiles([archiveURL]) }
//
//        let archive = libarchive(url: archiveURL)
//
//        // Load the archive to get entries
//        let loadedArchive = try await archive.loadArchive()
//
//        // Create a temporary directory for extraction
//        let extractDir = try createTempDirectory()
//        defer { cleanupTestFiles([extractDir]) }
//
//        // Get all flat entries
//        let allFlatEntries = loadedArchive.root.flatChildren()
//
//        // Select only specific entries (e.g., only files, not directories)
//        let fileEntries = allFlatEntries.filter { !$0.path.isEmpty && $0.header.type == .file }
//
//        // Prepare extractable entries
//        let extractable = ArchiveEntryExtractable(basePath: "", entries: fileEntries)
//
//        // Test extracting only specific entries
//        let extractedURLs = try await archive.extractEntries([extractable], toFolder: extractDir)
//
//        // Verify extraction results
//        #expect(!extractedURLs.isEmpty)
//        #expect(extractedURLs.count == fileEntries.count)
//
//        // Check that only the specified files were extracted
//        for url in extractedURLs {
//            let exists = FileManager.default.fileExists(atPath: url.path)
//            #expect(exists)
//
//            // Verify it's a file, not a directory
//            var isDir: ObjCBool = false
//            let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
//            #expect(fileExists && !isDir.boolValue)
//        }
//    }
}

// Custom error for test failures
struct TestError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        return message
    }
}
