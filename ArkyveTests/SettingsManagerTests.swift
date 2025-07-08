import Testing
@testable import Arkyve

@Suite("SettingsManager Tests")
@MainActor
final class SettingsManagerTests {
    var settingsManager: SettingsManager!
    
    init() {
        settingsManager = SettingsManager.shared
    }
    
    func testDefaultValues() {
        // Test default values for settings
        #expect(settingsManager.maxRecents == 9)
        #expect(settingsManager.newArchiveName == "Untitled")
        #expect(settingsManager.newArchiveFormat == .zip)
        #expect(settingsManager.folderExpansion == .oneOnly)
        #expect(settingsManager.autoSplashWindow == true)
        #expect(settingsManager.iconSize == 16)
        #expect(settingsManager.recents.isEmpty)
    }
    
    func testNewArchiveFilename() {
        // Test archive filename generation
        settingsManager.newArchiveName = "TestArchive"
        settingsManager.newArchiveFormat = .zip
        #expect(settingsManager.newArchiveFilename == "TestArchive.zip")
        
        settingsManager.newArchiveFormat = .tar
        #expect(settingsManager.newArchiveFilename == "TestArchive.tar")
    }
    
    func testRecentsManagement() {
        // Test adding and managing recent items
        let url1 = URLBookmark(url: URL(fileURLWithPath: "/test/path1"), bookmarkData: Data())
        let url2 = URLBookmark(url: URL(fileURLWithPath: "/test/path2"), bookmarkData: Data())
        let url3 = URLBookmark(url: URL(fileURLWithPath: "/test/path3"), bookmarkData: Data())

        // Add URLs
        settingsManager.addRecent(url1)
        settingsManager.addRecent(url2)
        settingsManager.addRecent(url3)
        
        // Check order and count
        #expect(settingsManager.recents.count == 3)
        #expect(settingsManager.recents[0] == url3)
        #expect(settingsManager.recents[1] == url2)
        #expect(settingsManager.recents[2] == url1)
        
        // Test adding duplicate
        settingsManager.addRecent(url2)
        #expect(settingsManager.recents.count == 3)
        #expect(settingsManager.recents[0] == url2)
        
        // Test clearing recents
        settingsManager.clearRecents()
        #expect(settingsManager.recents.isEmpty)
    }
    
    func testResetToDefaults() {
        // Modify settings
        settingsManager.newArchiveName = "CustomName"
        settingsManager.newArchiveFormat = .tar
        settingsManager.folderExpansion = .always
        settingsManager.autoSplashWindow = false
        settingsManager.iconSize = 32
        
        // Reset to defaults
        settingsManager.resetToDefaults()
        
        // Verify reset
        #expect(settingsManager.newArchiveName == "Untitled")
        #expect(settingsManager.newArchiveFormat == .zip)
        #expect(settingsManager.folderExpansion == .oneOnly)
        #expect(settingsManager.autoSplashWindow == true)
        #expect(settingsManager.iconSize == 16)
    }
} 
