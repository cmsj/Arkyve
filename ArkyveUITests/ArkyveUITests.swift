//
//  ArkyveUITests.swift
//  ArkyveUITests
//
//  Created by Chris Jones on 12/06/2025.
//

import XCTest

final class ArkyveUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    // MARK: - Window Tests
    
    func testSplashWindow() throws {
        // Verify splash window appears on launch
        let splashWindow = app.windows["Welcome to Arkyve"]
        XCTAssertTrue(splashWindow.exists, "Splash window should be visible on launch")
    }
    
    func testArchiveWindow() throws {
        // Navigate to Archive window

    }
    
    func testSettingsWindow() throws {
        // Navigate to Settings window
        let settingsButton = app.buttons["Settings"]
        settingsButton.click()
        
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.exists, "Settings window should be visible after clicking Settings button")
    }
    
    func testAboutWindow() throws {
        // Navigate to About window
        let aboutButton = app.buttons["About"]
        aboutButton.click()
        
        let aboutWindow = app.windows["About"]
        XCTAssertTrue(aboutWindow.exists, "About window should be visible after clicking About button")
    }
    
    func testLogWindow() throws {
        // Navigate to Log window
        let logButton = app.buttons["Log"]
        logButton.click()
        
        let logWindow = app.windows["Log"]
        XCTAssertTrue(logWindow.exists, "Log window should be visible after clicking Log button")
    }

    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
