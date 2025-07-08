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
        let extractedURLs = try await viewModel.extractAll(toFolder: tempDir)

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
        viewModel.saveArchiveWithTask(to: URLBookmark(url: tempFile, bookmarkData: Data()))

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
    
    @Test("UI state management")
    func testUIStateManagement() async throws {
        viewModel = manager.createVM(url: testURL)
        try await viewModel.waitForArchiveProgressTask()

        // Test initial UI state
        #expect(!viewModel.disableUI)
        #expect(!viewModel.disableNew)
        #expect(!viewModel.disableOpen)
        #expect(!viewModel.disableCloseWindow)
        #expect(!viewModel.disableAdd)
        #expect(viewModel.disableRevert)
        #expect(!viewModel.disableCloseArchive)
        #expect(viewModel.disableSave)
        #expect(!viewModel.disableSaveAs)
        #expect(viewModel.disableQuicklook) // Initially true because no entries are selected
        #expect(viewModel.disableExtract) // Initially true because no entries are selected
        #expect(!viewModel.disableExtractAll)

        // Test UI state during loading
        try await viewModel.waitForArchiveProgressTask()
        
        // Test UI state after loading
        #expect(!viewModel.disableUI)
        #expect(!viewModel.disableExtractAll) // Now false because entries are loaded
        
        // Test UI state with selected entries
        viewModel.selectedEntries.insert(viewModel.entries.first!.id)
        #expect(!viewModel.disableQuicklook)
        #expect(!viewModel.disableExtract)
        
        cleanup()
    }
    
    @Test("Dynamic UI text")
    func testDynamicUIText() async throws {
        viewModel = manager.createVM(url: testURL)
        
        // Test initial state
        #expect(viewModel.navSubtitleText == "")
        #expect(viewModel.statusBarText == "Working...")

        // Test after loading
        try await viewModel.waitForArchiveProgressTask()
        #expect(viewModel.statusBarText == "\(viewModel.entries.count) items")
        
        // Test with selected entries
        viewModel.selectedEntries.insert(viewModel.entries.first!.id)
        #expect(viewModel.statusBarText == "1 of \(viewModel.entries.count) selected")
        
        // Test with dirty state
        viewModel.setDirty()
        #expect(viewModel.navSubtitleText == "(Unsaved)")
        
        cleanup()
    }
    
    @Test("QuickLook functionality")
    func testQuickLook() async throws {
        viewModel = manager.createVM(url: testURL)
        
        try await viewModel.waitForArchiveProgressTask()
        
        // Test initial state
        #expect(viewModel.quickLookURL == nil)
        #expect(viewModel.quickLookItems.isEmpty)
        
        // Test with selected entry
        viewModel.selectedEntries.insert(viewModel.entries.first!.id)
        viewModel.extractForQuicklook()
        
        // Wait for extraction
        while viewModel.quickLookItems.isEmpty {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        #expect(!viewModel.quickLookItems.isEmpty)
        #expect(viewModel.quickLookURL != nil)
        
        // Test reset
        viewModel.resetQuickLook()
        #expect(viewModel.quickLookURL == nil)
        #expect(viewModel.quickLookItems.isEmpty)
        
        cleanup()
    }
    
//    @Test("Sort functionality")
//    func testSort() async throws {
//        viewModel = manager.createVM(url: testURL)
//        
//        try await viewModel.waitForArchiveProgressTask()
//        
//        // Sort by name in ascending order
//        viewModel.sort(using: [KeyPathComparator(\ArchiveEntry.name, order: .forward)])
//        let sortedByName = viewModel.entries.sorted { $0.name < $1.name }
//        #expect(viewModel.entries.map { $0.name } == sortedByName.map { $0.name })
//        
//        // Sort by name in descending order
//        viewModel.sort(using: [KeyPathComparator(\ArchiveEntry.name, order: .reverse)])
//        let sortedByNameDesc = viewModel.entries.sorted { $0.name > $1.name }
//        #expect(viewModel.entries.map { $0.name } == sortedByNameDesc.map { $0.name })
//        
//        cleanup()
//    }
    
    @Test("Error handling")
    func testErrorHandling() async throws {
        // Test with non-existent file
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.zip")
        viewModel = manager.createVM(url: nonExistentURL)
        
        await #expect(throws: ArkyveError.self) {
            try await self.viewModel.waitForArchiveProgressTask()
        }

        #expect(viewModel.errors.error != nil)
        
        cleanup()
    }
} 
