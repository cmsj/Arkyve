import Testing
import Foundation
@testable import Arkyve

@Suite("ArchiveViewModel Tests", .serialized)
@MainActor
final class ArchiveViewModelTests {
    var manager: ManagerManager!
    var viewModel: ArchiveViewModel!
    var testURL: URL!
    
    init() {
        manager = ManagerManager.shared
        let bundle = Bundle(for: ArchiveEntryTests.self)
        testURL = bundle.url(forResource: "helloworld", withExtension: "zip")!
    }
    
    func cleanup() {
        manager.removeAllVMs()
    }
    
    @Test("Initial state")
    func testInitialState() {
        viewModel = manager.createVM(url: testURL)
        
        #expect(!manager.vmStoreIsEmpty)
        #expect(viewModel.diskURL == testURL)
        #expect(viewModel.name == testURL.lastPathComponent)
        #expect(!viewModel.dirty)
        #expect(viewModel.selectedEntries.isEmpty)
        #expect(viewModel.entries.isEmpty) // Initially empty until loaded
        #expect(viewModel.errors.error == nil)
        cleanup()
    }
    
    @Test("Load archive")
    func testLoadArchive() async throws {
        viewModel = manager.createVM(url: testURL)
        
        try await viewModel.waitForArchiveProgressTask()

        #expect(!viewModel.entries.isEmpty)
        #expect(viewModel.root.children != nil)
        #expect(!viewModel.dirty)
        #expect(viewModel.errors.error == nil)
        cleanup()
    }
    
    @Test("Extract archive")
    func testExtractArchive() async throws {
        viewModel = manager.createVM(url: testURL)
        
        try await viewModel.waitForArchiveProgressTask()

        // Create a temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Extract all entries
        let extractedURLs = try await viewModel.extract(toFolder: tempDir)
        
        #expect(!extractedURLs.isEmpty)
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("helloworld").appendingPathComponent("hello.txt").path))
        cleanup()
    }
    
    @Test("Save archive")
    func testSaveArchive() async throws {
        viewModel = manager.createVM(url: testURL)

        try await viewModel.waitForArchiveProgressTask()

        // Create a temporary file for saving
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try FileManager.default.createDirectory(at: tempFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        // Save the archive
        await viewModel.saveArchive(to: tempFile)

        try await viewModel.waitForArchiveProgressTask()

        #expect(viewModel.errors.error == nil)
        #expect(FileManager.default.fileExists(atPath: tempFile.path))
        #expect(!viewModel.dirty)
        cleanup()
    }
    
    @Test("Add files to archive")
    func testAddFiles() async throws {
        viewModel = manager.createVM(url: testURL)
        
        try await viewModel.waitForArchiveProgressTask()

        let initialCount = viewModel.entries.count
        
        // Create a temporary file to add
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        // Add the file to the archive
        try viewModel.addFiles(from: [tempFile], parent: viewModel.root)
        
        #expect(viewModel.entries.count > initialCount)
        #expect(viewModel.dirty)
        cleanup()
    }
    
    @Test("Remove entries from archive")
    func testRemoveEntries() async throws {
        viewModel = manager.createVM(url: testURL)

        try await viewModel.waitForArchiveProgressTask()

        let initialCount = viewModel.entries.count
        let entryToRemove = viewModel.entries.first!
        
        viewModel.removeEntries([entryToRemove.id])
        
        #expect(viewModel.entries.count < initialCount)
        #expect(viewModel.dirty)
        cleanup()
    }
} 
