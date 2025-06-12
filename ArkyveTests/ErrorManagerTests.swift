import Testing
import Foundation
@testable import Arkyve

@Suite("ErrorManager Tests")
@MainActor
final class ErrorManagerTests {
    @Test("Initial state")
    func testInitialState() {
        let manager = ErrorManager()
        #expect(manager.show == false)
        #expect(manager.error == nil)
    }
    
    @Test("Setting an error")
    func testSettingError() {
        let manager = ErrorManager()
        let error = ArkyveError(.openArchive, msg: "Test error message")
        
        manager.err(error)
        
        #expect(manager.error == error)
        #expect(manager.error?.kind == .openArchive)
        #expect(manager.error?.msg == "Test error message")
    }
    
    @Test("Clearing an error")
    func testClearingError() {
        let manager = ErrorManager()
        let error = ArkyveError(.openArchive, msg: "Test error message")
        
        manager.err(error)
        #expect(manager.error != nil)
        
        manager.clear()
        #expect(manager.error == nil)
    }
    
    @Test("Cancelled error with empty message")
    func testCancelledError() {
        let manager = ErrorManager()
        let error = ArkyveError(.cancelled, msg: "")
        
        manager.err(error)
        
        #expect(manager.error?.kind == .cancelled)
        #expect(manager.error?.msg == "User cancelled operation.")
    }
} 
