import Testing
import Foundation
@testable import Arkyve

@Suite("ManagerManager Tests", .serialized)
@MainActor
final class ManagerManagerTests {
    var manager: ManagerManager!
    
    init() {
        manager = ManagerManager.shared
    }

    // FIXME: This can't be a deinit until Swift 6.2. Once we can do that, remove all the cleanup() calls below and remove .serialized above
//    deinit {
    func cleanup() {
        // Clean up any remaining VMs
        manager.removeAllVMs()
    }
    
    @Test("Initial state")
    func testInitialState() {
        #expect(manager.vmStoreIsEmpty)
        #expect(!manager.isQuitting)
        cleanup()
    }
    
    @Test("Create VM with URL")
    func testCreateVMWithURL() throws {
        let bundle = Bundle(for: ArchiveEntryTests.self)
        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
        
        let vm = manager.createVM(url: testURL)
        
        #expect(!manager.vmStoreIsEmpty)
        #expect(vm.diskURL == testURL)
        #expect(vm.name == testURL.lastPathComponent)
        cleanup()
    }
    
    @Test("Create VM without URL")
    func testCreateVMWithoutURL() {
        let vm = manager.findOrCreateVM()
        
        #expect(!manager.vmStoreIsEmpty)
        #expect(vm.diskURL == nil)
        #expect(vm.name == SettingsManager.shared.newArchiveFilename)
        cleanup()
    }
    
    @Test("Find existing VM")
    func testFindExistingVM() {
        let vm1 = manager.findOrCreateVM()
        let vm2 = manager.findOrCreateVM(vm1.id)
        
        #expect(vm1 === vm2) // Same instance
        #expect(manager.vmStoreCount == 1)
        cleanup()
    }
    
    @Test("Remove VM")
    func testRemoveVM() {
        let vm = manager.findOrCreateVM()
        #expect(!manager.vmStoreIsEmpty)
        
        manager.removeVM(vm)
        #expect(manager.vmStoreIsEmpty)
        cleanup()
    }
    
    @Test("Create VM with truncation")
    func testCreateVMWithTruncation() throws {
        let bundle = Bundle(for: ArchiveEntryTests.self)
        let testURL = bundle.url(forResource: "hello", withExtension: "txt")!
        
        let vm = manager.createVM(url: testURL, truncateAt: 5)
        
        #expect(!manager.vmStoreIsEmpty)
        #expect(vm.truncateAt == 5)
        cleanup()
    }
} 
