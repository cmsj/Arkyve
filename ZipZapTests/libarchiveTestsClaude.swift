//
//  libarchiveTestsClaude.swift
//  ZipZap
//
//  Created by Chris Jones on 09/03/2025.
//

import Testing
import Foundation
@testable import ZipZap // Assuming your module is named ZipZap

@Suite("libarchiveTestsClaude", .serialized)
struct libarchiveTestsClaudeLOL {

    // MARK: - Test Helpers

    /// Creates a temporary archive file for testing
    func createTestArchive() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let archiveURL = tempDir.appendingPathComponent("test_archive.zip")

        // Create a simple zip file with test content
        // This is a simplified approach - in a real test, you might use a pre-made test archive
        // or create one using the system's zip command
        let testFileURL = tempDir.appendingPathComponent("test_file.txt")
        try "Test content".write(to: testFileURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = [archiveURL.path, testFileURL.path]
        process.currentDirectoryURL = tempDir
        try process.run()
        process.waitUntilExit()

        try FileManager.default.removeItem(at: testFileURL)

        return archiveURL
    }

    /// Cleans up temporary files after tests
    func cleanupTestFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Tests

    @Test("Read archive entries, format, and filters")
    func testReadEntriesFormatFilters() async throws {
        // Create a test archive
        let archiveURL = try createTestArchive()
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchive(url: archiveURL)

        // Test reading entries, format, and filters
        let (format, filters, headers) = try await archive.readEntriesFormatFilters()

        // Verify format is recognized
        #expect(format != .Unknown)

        // Verify we have at least one filter
        #expect(!filters.isEmpty)

        // Verify we have at least one entry (our test file)
        #expect(!headers.isEmpty)

        // Verify the entry has the expected properties
        let entry = headers.first
        #expect(entry != nil)
        #expect(entry?.source.type == .Archive)
        #expect(entry?.type == .file)
        #expect(entry?.size ?? 0 > 0)
    }

    @Test("Load archive")
    func testLoadArchive() async throws {
        // Create a test archive
        let archiveURL = try createTestArchive()
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchive(url: archiveURL)

        // Test loading the archive
        let loadedArchive = try await archive.loadArchive()

        // Verify the loaded archive has the expected properties
        #expect(loadedArchive.URL == archiveURL)
        #expect(loadedArchive.root != nil)
        #expect(loadedArchive.entries.count > 0)
        #expect(loadedArchive.format != .Unknown)
        #expect(!loadedArchive.filters.isEmpty)
    }

//    @Test("Extract entries")
//    func testExtractEntries() async throws {
//        // Create a test archive
//        let archiveURL = try createTestArchive()
//        defer { cleanupTestFiles([archiveURL]) }
//
//        let archive = libarchive(url: archiveURL)
//
//        // Load the archive to get entries
//        let loadedArchive = try await archive.loadArchive()
//
//        // Create a temporary directory for extraction
//        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
//        defer { cleanupTestFiles([extractDir]) }
//
//        // Prepare extractable entries
//        let flatEntries = loadedArchive.root.flatChildren()
//        let extractable = ArchiveEntryExtractable(basePath: "", entries: flatEntries)
//
//        // Test extracting entries
//        let extractedURLs = try await archive.extractEntries([extractable], toFolder: extractDir)
//
//        // Verify extraction results
//        #expect(!extractedURLs.isEmpty)
//
//        // Check that files were actually extracted
//        for url in extractedURLs {
//            let exists = FileManager.default.fileExists(atPath: url.path)
//            #expect(exists)
//        }
//    }

//    @Test("Extract entries with path retention")
//    func testExtractEntriesWithPathRetention() async throws {
//        // Create a test archive
//        let archiveURL = try createTestArchive()
//        defer { cleanupTestFiles([archiveURL]) }
//
//        let archive = libarchive(url: archiveURL)
//
//        // Load the archive to get entries
//        let loadedArchive = try await archive.loadArchive()
//
//        // Create a temporary directory for extraction
//        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
//        defer { cleanupTestFiles([extractDir]) }
//
//        // Prepare extractable entries
//        let flatEntries = loadedArchive.root.flatChildren()
//        let extractable = ArchiveEntryExtractable(basePath: "", entries: flatEntries)
//
//        // Test extracting entries with path retention
//        let extractedURLs = try await archive.extractEntries([extractable], toFolder: extractDir, retainFullPath: true)
//
//        // Verify extraction results
//        #expect(!extractedURLs.isEmpty)
//
//        // Check that files were extracted with full paths
//        for url in extractedURLs {
//            let exists = FileManager.default.fileExists(atPath: url.path)
//            #expect(exists)
//        }
//    }

    @Test("Write archive")
    func testWriteArchive() async throws {
        // Create a test archive
        let archiveURL = try createTestArchive()
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchive(url: archiveURL)

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
        let newArchiveLib = libarchive(url: newArchiveURL)
        let (format, filters, headers) = try await newArchiveLib.readEntriesFormatFilters()

        // Verify the new archive has the expected format, filters, and entries
        #expect(format == loadedArchive.format)
        #expect(filters.count == loadedArchive.filters.count)
        print(headers)
        print(flatEntries)
        #expect(headers.count == flatEntries.count - 1) // -1 because the root entry isn't stored in the archive
    }

    @Test("Read date helper method")
    func testReadDate() async throws {
        // This is a private method, so we'll test it indirectly through the public API
        let archiveURL = try createTestArchive()
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchive(url: archiveURL)

        // Read entries which will use the readDate method internally
        let (_, _, headers) = try await archive.readEntriesFormatFilters()

        // Verify dates were read
        let entry = headers.first
        #expect(entry != nil)

        // At least one of these dates should be non-zero
        let hasValidDate = entry!.atime != Date(since: 0) ||
        entry!.ctime != Date(since: 0) ||
        entry!.mtime != Date(since: 0) ||
        entry!.btime != Date(since: 0)

        #expect(hasValidDate)
    }

    @Test("Entry path helper method")
    func testEntryPath() async throws {
        // This is a private method, so we'll test it indirectly through the public API
        let archiveURL = try createTestArchive()
        defer { cleanupTestFiles([archiveURL]) }

        let archive = libarchive(url: archiveURL)

        // Read entries which will use the entryPath method internally
        let (_, _, headers) = try await archive.readEntriesFormatFilters()

        // Verify paths were read
        let entry = headers.first
        #expect(entry != nil)
        #expect(!entry!.path.isEmpty)
        #expect(entry!.path != "Unknown")

        // Verify trailing slashes were removed
        #expect(entry!.path.last != "/")
    }

    @Test("Error handling for non-existent archive")
    func testErrorHandlingForNonExistentArchive() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/path/to/nonexistent.zip")
        let archive = libarchive(url: nonExistentURL)

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

        let archive = libarchive(url: invalidArchiveURL)

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
}
